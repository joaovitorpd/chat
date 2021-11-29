import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TextComposer extends StatefulWidget {
  TextComposer(this.sendMessage);

  final Function({String text, File imgFile}) sendMessage;


  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;


  void _reset() {
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 50,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo_camera),
            onPressed: () async{
              FocusScope.of(context).unfocus();
              final XFile? imgFile = await ImagePicker().pickImage(source:ImageSource.camera);
              if(imgFile == null) return;
              final File file = File(imgFile.path);
              widget.sendMessage(imgFile:file);
            },
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration:
                  InputDecoration.collapsed(hintText: "Enviar uma Mensagem"),
              onChanged: (text) {
                setState(() {
                  _isComposing = text.isNotEmpty;
                });
              },
              onSubmitted: (text) {
                widget.sendMessage(text: text);
                _reset();
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _isComposing ? () {
              FocusScope.of(context).unfocus();
              widget.sendMessage(text: _controller.text);
              _reset();
            } : null,
          ),
        ],
      ),
    );
  }
}
