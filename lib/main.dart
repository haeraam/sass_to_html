import 'dart:convert';
import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:styled_text/styled_text.dart';
import 'package:universal_html/html.dart' as html;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.yellow,
          selectionColor: Colors.green,
          selectionHandleColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class UploadedScss {
  final String name;
  final String code;
  UploadedScss({
    required this.name,
    required this.code,
  });
}

class ConvertedHtml {
  ConvertedHtml({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

class _MyHomePageState extends State<MyHomePage> {
  String _res = 'upload scss please...';
  List _downLoadWaitList = [];
  List<UploadedScss> _waitList = [];
  List<ConvertedHtml> _convertedList = [];

  String _openTag({
    required String tagName,
    required int depth,
    String className = '',
  }) {
    String indent = '  ' * depth;
    return switch (tagName) {
      'Link' => '$indent&lt;<tag>Link</tag> href ="" <class>className</class><equal>=</equal><className>{SignInStyleEntity.$className}</className>/&gt;\n',
      'Image' => '$indent&lt;<tag>Image</tag> src="" alt ="" fill={true} <class>className</class><equal>=</equal><className>{SignInStyleEntity.$className}</className>/&gt;\n',
      _ => '$indent&lt;<tag>$tagName</tag> <class>className</class><equal>=</equal><className>{SignInStyleEntity.$className}</className>&gt;\n',
    };
  }

  String _closeTag({
    required String tagName,
    required int depth,
  }) {
    String indent = '  ' * depth;
    return switch (tagName) {
      'Link' || 'Image' => '',
      _ => '$indent&lt;/<tag>$tagName</tag>&gt;\n',
    };
  }

  _getTageName({required String className, required String contents}) {
    final classNameWithTagNamePattern = RegExp('\\.$className\\s*[\\{|,]\\n.*//([a-zA-Z]+)');
    final tagMatch = classNameWithTagNamePattern.firstMatch(contents);
    final tagName = tagMatch?.group(1) ?? 'div';
    return tagName;
  }

  Future<String> _convertScssToHtml(String contents) async {
    String result = '';

    final classNamePattern = RegExp(r'\.([a-zA-Z0-9_-]+)\s*[\{|,]');
    final closeTagPattern = RegExp(r'\}');

    List contentsByLine = contents.split('\n');

    List tagStak = [];
    bool findMediaTag = false;
    for (String line in contentsByLine) {
      print(line);
      final matchedClassName = classNamePattern.firstMatch(line);
      final matchCloseTag = closeTagPattern.firstMatch(line);

      if (line.contains('@media') || line.contains('@include mobile')) findMediaTag = true;
      if (findMediaTag) continue;

      if (matchedClassName != null) {
        print('tagOpen!!!');
        String className = matchedClassName[1] ?? '';
        String tagName = _getTageName(className: className, contents: contents);
        result += _openTag(tagName: tagName, className: className, depth: tagStak.length);
        tagStak.add(tagName);
        if (line.contains(',')) {
          tagStak.removeLast();
          result += _closeTag(tagName: tagName, depth: tagStak.length);
        }
      } else if (matchCloseTag != null && tagStak.isNotEmpty) {
        print('tagClose!!!');
        String tagName = tagStak.last;
        tagStak.removeLast();
        result += _closeTag(tagName: tagName, depth: tagStak.length);
      }
      print(tagStak);
    }
    return result;
  }

  _onClickUpload() async {
    FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['scss'],
    );
    if (pickedFile != null) {
      for (var flieData in pickedFile.files) {
        String code = '';
        if (kIsWeb) {
          code = String.fromCharCodes(flieData.bytes!);
        } else {
          if (Platform.isMacOS) {
            code = File(flieData.path!).readAsStringSync();
          }
        }

        UploadedScss file = UploadedScss(name: flieData.name.split('.').first, code: code);
        _waitList.add(file);
      }
      setState(() {});
    } else {
      //파일 불러오기 실패시
    }
  }

  _onClickConvert() async {
    if (_waitList.isNotEmpty) {
      _convertedList = await Future.wait(_waitList.map((scss) async {
        String code = await _convertScssToHtml(scss.code);
        return ConvertedHtml(code: code, name: scss.name);
      }));
      setState(() {});
    }
  }

  _onClickDownload() async {
    if (kIsWeb) {
      for (var html in _convertedList) {
        _downloadFileInBorwser(html.name, html.code.replaceAll(RegExp(r'<.*?>'), '').replaceAll('&lt;', '<').replaceAll('&gt;', '>'));
      }
    } else {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      for (var html in _convertedList) {
        if (Platform.isMacOS) {
          final savedFile = File('$selectedDirectory/${html.name.split('/').last.split('.').first}.html');
          await savedFile.writeAsString(html.code.replaceAll(RegExp(r'<.*?>'), '').replaceAll('&lt;', '<').replaceAll('&gt;', '>'));
        } else {}
      }
    }

    _downLoadWaitList.clear();
  }

  void _downloadFileInBorwser(String fileName, String content) {
    // 문자열을 Uint8List 데이터로 변환
    Uint8List data = Uint8List.fromList(utf8.encode(content));
    // Blob 생성
    final blob = html.Blob([data]);
    // Blob에서 Object URL 생성
    final url = html.Url.createObjectUrlFromBlob(blob);
    // 다운로드 링크 생성
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", '$fileName.html')
      ..click();
    // Object URL 해제
    html.Url.revokeObjectUrl(url);
  }

  _onClickClear() {
    _res = '';
    _downLoadWaitList = [];
    _waitList = [];
    _convertedList = [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ElevatedButton(onPressed: _onClickUpload, child: const Text('upload')),
                    ElevatedButton(onPressed: _onClickClear, child: const Text('clear')),
                    ElevatedButton(onPressed: _onClickConvert, child: const Text('convert')),
                    ElevatedButton(onPressed: _onClickDownload, child: const Text('download')),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _convertedList.isEmpty
                      ? DropTarget(
                          onDragDone: (detail) async {
                            for (var file in detail.files) {
                              if (file.name.split('.').last == 'scss') {
                                String code = await file.readAsString();
                                _waitList.add(UploadedScss(name: file.name.split('.').first, code: code));
                              }
                            }
                            setState(() {});
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 413),
                            width: double.infinity,
                            padding: const EdgeInsets.all(40),
                            margin: const EdgeInsets.symmetric(horizontal: 80),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: const Color.fromARGB(255, 40, 42, 54),
                            ),
                            child: _waitList.isEmpty
                                ? const Center(
                                    child: Text(
                                    'drag and drop file\nor\npress upload button',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                    ),
                                  ))
                                : Wrap(
                                    children: [..._waitList.map((file) => FileCard(scss: file))],
                                  ),
                          ),
                        )
                      : Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: CarouselSlider(
                            options: CarouselOptions(
                              disableCenter: true,
                              enableInfiniteScroll: false,
                            ),
                            items: _convertedList
                                .map((item) => CustomScrollView(
                                      slivers: [
                                        SliverFillRemaining(
                                          hasScrollBody: false,
                                          child: Column(
                                            children: <Widget>[
                                              Text(
                                                item.name,
                                                style: TextStyle(fontSize: 20),
                                              ),
                                              SizedBox(height: 20),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(40),
                                                  margin: const EdgeInsets.symmetric(horizontal: 10),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(25),
                                                    color: const Color.fromARGB(255, 40, 42, 54),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    child: Container(
                                                      child: Center(child: CodeText(code: item.code)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ))
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 32)
              ],
            ),
          )
        ],
      ),
    );
  }
}

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.scss});
  final UploadedScss scss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 95,
      height: 95,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Color.fromARGB(75, 201, 204, 220)),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity, // 넘어가는 부분 허용
                maxHeight: double.infinity, // 넘어가는 부분 허용
                child: SvgPicture.asset(
                  'assets/images/sass_logo.svg',
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                ),
              ),
            ),
            Text(
              scss.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CodeText extends StatelessWidget {
  const CodeText({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: StyledText(
        text: code,
        style: const TextStyle(
          height: 1.5,
          fontSize: 16,
          color: Colors.white,
        ),
        tags: {
          'tag': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 121, 198))),
          'equal': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 121, 198))),
          'class': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 80, 250, 123))),
          'className': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 244, 137))),
        },
      ),
    );
  }
}
