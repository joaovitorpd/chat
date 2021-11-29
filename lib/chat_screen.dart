import 'dart:io';

import 'package:chat/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  Future<User?> _getUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final GoogleSignInAccount? googleSignInAccount =
          await googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount!.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
        accessToken: googleSignInAuthentication.accessToken,
      );

      final UserCredential authResult =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = authResult.user;
      return user;
    } catch (error) {}
  }

  void _sendMessage({String? text, File? imgFile}) async {
    final User? user = await _getUser();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Não foi possível fazer o login. Tente novamente!'),
        backgroundColor: Colors.red,
      ));
    }

    //Após login, as informações do usuário são armazenadas no Mapa data
    Map<String, dynamic> data = {
      "uid": user!.uid,
      "senderName": user.displayName,
      "senderPhotoUrl": user.photoURL,
      "time": Timestamp.now(),
    };

    //Caso haja imagem do usuário, o seu endereço é lido
    if (imgFile != null) {
      //Obteve a referência do FirebaseStorage e usa a função child para dar
      // nome ao arquivo (mas o .child pode ser usado para criar pastas também),
      // que é dado como texto do horário da mensagem
      //OBS: correto (mas não será feito aqui por praticidade)
      // seria ter uma pasta por usuário:
      /*
      UploadTask task = FirebaseStorage.instance
          .ref()
          .child(uid)
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(imgFile);
      */

      UploadTask task = FirebaseStorage.instance
          .ref()
          .child(user.uid + DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(imgFile);

      setState(() {
        _isLoading = true;
      });

      TaskSnapshot taskSnapshot = await task.whenComplete(() => null);
      String url = await taskSnapshot.ref.getDownloadURL();
      data['imgURL'] = url;

      setState(() {
        _isLoading = false;
      });


    }

    //Leitura do texto
    if (text != null) data['text'] = text;

    //Feito o envio para o Firebase
    FirebaseFirestore.instance.collection('messages').add(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _currentUser != null ? 'Olá, ${_currentUser!.displayName}' : 'Chat App'
        ),
        elevation: 0,
        actions: [
          _currentUser != null ? IconButton(
            icon: Icon(Icons.exit_to_app),
              onPressed: () {
              FirebaseAuth.instance.signOut();
              googleSignIn.signOut();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Você saiu com sucesso!'),
              ));
              }
            , ) : Container()
        ],
      ),
      body: GestureDetector(
        child: Column(
          children: [
            Expanded(
              //O Snapshot nada mais é do que uma Stream.
              // A Stream permite que o aplicativo vá recebendo dados continuamente.
              // O Future retorna os dados apenas uma vez, mas a Stream retorna os dados
              // sempre que houver alguma modificação.
              // Assim, sempre que houver uma modificação na coleção “messages”, a Stream
              // será acionada e reconstruirá a tela com os dados atualizados.
              //O Firebase só possibilita ordenar por um campo.
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('messages').orderBy('time').snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    default:
                      List<DocumentSnapshot> documents = snapshot.data!.docs.reversed.toList();

                      return ListView.builder(
                        itemCount: documents.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          return ChatMessage(
                              documents[index].data() as Map<String, dynamic>,
                              documents[index].get('uid') == _currentUser?.uid,
                          );
                        },
                      );
                  }
                },
              ),
            ),
            _isLoading ? LinearProgressIndicator() : Container(),
            TextComposer(_sendMessage),
          ],
        ),
        onTap: () {
          FocusScope.of(context).requestFocus(new FocusNode());
        },
      ),
    );
  }
}
