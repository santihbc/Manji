import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_review/app_review.dart';

import 'package:kanji_dictionary/utils/list_extension.dart';
import 'package:kanji_dictionary/bloc/kanji_bloc.dart';
import 'package:kanji_dictionary/bloc/sentence_bloc.dart';
import 'package:kanji_dictionary/bloc/kanji_list_bloc.dart';
import 'package:kanji_dictionary/ui/components/fancy_icon_button.dart';
import 'kana_detail_page.dart';
import 'sentence_detail_page.dart';
import 'word_detail_page.dart';
import 'components/furigana_text.dart';
import 'components/custom_bottom_sheet.dart' as CustomBottomSheet;
import 'components/chip_collections.dart';
import 'components/label_divider.dart';

class KanjiDetailPage extends StatefulWidget {
  final Kanji kanji;
  final String kanjiStr;

  KanjiDetailPage({this.kanji, this.kanjiStr}) : assert(kanji != null || kanjiStr != null);

  @override
  State<StatefulWidget> createState() => _KanjiDetailPageState();
}

class _KanjiDetailPageState extends State<KanjiDetailPage> with SingleTickerProviderStateMixin {
  final scrollController = ScrollController();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final sentenceBloc = SentenceBloc();
  String kanjiStr;
  bool isFaved;
  bool isStared;
  Kanji kanji;
  double elevation = 0;
  double opacity = 0;

  @override
  void initState() {
    kanjiStr = widget.kanjiStr ?? widget.kanji.kanji;
    isFaved = kanjiBloc.getIsFaved(kanjiStr);
    isStared = kanjiBloc.getIsStared(kanjiStr);

    super.initState();

    scrollController.addListener(() {
      if (this.mounted && scrollController.offset == scrollController.position.maxScrollExtent) {
        //kanjiBloc.getMoreSentencesByKanji();
        sentenceBloc.getMoreSentencesByKanji();
      }
    });

    scrollController.addListener(() {
      double offset = scrollController.offset;
      if (this.mounted) {
        if (offset <= 0) {
          setState(() {
            elevation = 0;
            opacity = 0;
          });
        } else {
          setState(() {
            elevation = 8;
            if (offset > 200)
              opacity = 1;
            else
              opacity = offset / 200;
          });
        }
      }
    });

    sentenceBloc.getSentencesByKanji(kanjiStr);
    sentenceBloc.fetchWordsByKanji(kanjiStr);
    // kanjiBloc.getSentencesByKanji(widget.kanjiStr ?? widget.kanji.kanji);
    //kanjiBloc.fetchWordsByKanji(widget.kanjiStr ?? widget.kanji.kanji);
    if (widget.kanjiStr != null) kanjiBloc.getKanjiInfoByKanjiStr(widget.kanjiStr);


    AppReview.isRequestReviewAvailable.then((isAvailable) {
      if (isAvailable) {
        AppReview.requestReview;
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    sentenceBloc.dispose();
    kanjiBloc.reset();
    //kanjiBloc.resetSentencesFetcher();
    super.dispose();
  }

  void onPressed() {
    launchURL(kanji.kanji);
  }

  String getAppBarInfo() {
    String str = '';
    if (kanji.jlpt != 0) {
      str += "N${kanji.jlpt}";
    }

    if (kanji.grade >= 0) {
      if (kanji.grade > 3) {
        str += ' ${kanji.grade}th Grade';
      } else {
        switch (kanji.grade) {
          case 1:
            str += ' 1st Grade';
            break;
          case 2:
            str += ' 2nd Grade';
            break;
          case 3:
            str += ' 3rd Grade';
            break;
          case 0:
            str += ' Junior High';
            break;
          default:
            throw Exception('Unmatched grade');
        }
      }
    }

    return str.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          elevation: elevation,
          title: Opacity(
            opacity: opacity,
            child: StreamBuilder(
              stream: kanjiBloc.kanji,
              builder: (_, AsyncSnapshot<Kanji> snapshot) {
                if (snapshot.hasData || widget.kanji != null) {
                  var kanji = widget.kanji == null ? snapshot.data : widget.kanji;
                  this.kanji = kanji;
                  return Text(getAppBarInfo());
                } else {
                  return Container();
                }
              },
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(FontAwesomeIcons.wikipediaW),
              onPressed: onPressed,
            ),
            IconButton(
              icon: Icon(Icons.playlist_add),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) {
                      return Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: Material(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                            child: StreamBuilder(
                                stream: KanjiListBloc.instance.kanjiLists,
                                builder: (_, AsyncSnapshot<List<KanjiList>> snapshot) {
                                  if (snapshot.hasData) {
                                    var kanjiLists = snapshot.data;

                                    if (kanjiLists.isEmpty) {
                                      return Container(
                                        height: 200,
                                        child: Center(
                                          child: Text(
                                            "You don't have any list yet.",
                                            style: TextStyle(color: Colors.black54),
                                          ),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                        shrinkWrap: true,
                                        itemBuilder: (_, index) {
                                          var kanjiList = kanjiLists[index];
                                          var isInList = KanjiListBloc.instance.isInList(kanjiList.name, kanjiStr);

                                          return ListTile(
                                            title: Text(kanjiLists[index].name, style: TextStyle(color: isInList ? Colors.black54 : Colors.black)),
                                            subtitle: Text('${kanjiLists[index].kanjiStrs.length} Kanji'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              if (isInList) {
                                                scaffoldKey.currentState.hideCurrentSnackBar();
                                                scaffoldKey.currentState.showSnackBar(SnackBar(
                                                  content: Text(
                                                    'This kanji is already in ${kanjiList.name}',
                                                    style: TextStyle(color: Colors.black),
                                                  ),
                                                  backgroundColor: Theme.of(context).accentColor,
                                                  action: SnackBarAction(
                                                    label: 'Dismiss',
                                                    onPressed: () => scaffoldKey.currentState.hideCurrentSnackBar(),
                                                    textColor: Colors.blueGrey,
                                                  ),
                                                ));
                                              } else {
                                                KanjiListBloc.instance.addKanji(kanjiList.name, kanjiStr);
                                                scaffoldKey.currentState.hideCurrentSnackBar();
                                                scaffoldKey.currentState.showSnackBar(SnackBar(
                                                  content: Text(
                                                    '$kanjiStr has been added to ${kanjiList.name}',
                                                    style: TextStyle(color: Colors.black),
                                                  ),
                                                  backgroundColor: Theme.of(context).accentColor,
                                                  action: SnackBarAction(
                                                    label: 'Dismiss',
                                                    onPressed: () => scaffoldKey.currentState.hideCurrentSnackBar(),
                                                    textColor: Colors.blueGrey,
                                                  ),
                                                ));
                                              }
                                            },
                                          );
                                        },
                                        separatorBuilder: (_, index) => Divider(height: 0),
                                        itemCount: kanjiLists.length);
                                  } else {
                                    return Container();
                                  }
                                }),
                          ),
                        ),
                      );
                    });
              },
            ),
            FancyIconButton(
              isFaved: isFaved,
              color: Colors.red,
              icon: Icons.favorite,
              iconBorder: Icons.favorite_border,
              onTapped: () {
                setState(() {
                  isFaved = !isFaved;
                });
                if (isFaved) {
                  kanjiBloc.addFav(kanjiStr);
                } else {
                  kanjiBloc.removeFav(kanjiStr);
                }
              },
            ),
            IconButton(
                icon: AnimatedCrossFade(
                    firstChild: Icon(FontAwesomeIcons.solidBookmark, color: Colors.teal),
                    secondChild: Icon(FontAwesomeIcons.bookmark),
                    crossFadeState: isStared ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: Duration(microseconds: 200)),
                onPressed: () {
                  setState(() {
                    isStared = !isStared;
                  });
                  if (isStared) {
                    kanjiBloc.addStar(kanjiStr);
                  } else {
                    kanjiBloc.removeStar(kanjiStr);
                  }
                }),
          ],
        ),
        body: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: <Widget>[
              Container(
                child: Flex(
                  direction: Axis.horizontal,
                  children: <Widget>[
                    Flexible(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Container(
                              decoration: BoxDecoration(
                                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)], shape: BoxShape.rectangle, color: Colors.white),
                              height: MediaQuery.of(context).size.width / 2 - 24,
                              child: Center(
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                        child: Image.asset(
                                      'data/matts.png',
                                    )),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Center(
                                          child: Hero(
                                              tag: widget.kanjiStr ?? widget.kanji.kanji,
                                              child: Material(
                                                //wrap the text in Material so that Hero transition doesn't glitch
                                                color: Colors.transparent,
                                                child: Text(
                                                  widget.kanjiStr ?? widget.kanji.kanji,
                                                  style: TextStyle(fontFamily: 'strokeOrders', fontSize: 128),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ))),
                                    )
                                  ],
                                ),
                                //child: Text(widget.kanjiStr ?? widget.kanji.kanji, style: TextStyle(fontFamily: 'strokeOrders', fontSize: 148))
                              )),
                        ),
                        flex: 1),
                    Flexible(child: buildKanjiInfoColumn(), flex: 1),
                  ],
                ),
              ),
              StreamBuilder(
                stream: kanjiBloc.kanji,
                builder: (_, AsyncSnapshot<Kanji> snapshot) {
                  if (snapshot.hasData || widget.kanji != null) {
                    var kanji = widget.kanji == null ? snapshot.data : widget.kanji;
                    this.kanji = kanji;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      LabelDivider(
                                          child: RichText(
                                              textAlign: TextAlign.center,
                                              text: TextSpan(children: [
                                                TextSpan(text: 'いみ' + '\n', style: TextStyle(fontSize: 9, color: Colors.white)),
                                                TextSpan(text: '意味', style: TextStyle(fontSize: 18, color: Colors.white))
                                              ]))),
                                      Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text("${kanji.meaning}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  LabelDivider(
                                      child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(children: [
                                            TextSpan(text: 'よみ      かた' + '\n', style: TextStyle(fontSize: 9, color: Colors.white)),
                                            TextSpan(text: '読み方', style: TextStyle(fontSize: 18, color: Colors.white))
                                          ]))),
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    direction: Axis.horizontal,
                                    children: <Widget>[
                                      Padding(
                                        padding: EdgeInsets.all(4),
                                        child: FuriganaText(
                                          text: '音読み',
                                          tokens: [Token(text: '音読み', furigana: 'おんよみ')],
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ),
                                      for (var onyomi in kanji.onyomi)
                                        Padding(
                                            padding: EdgeInsets.all(4),
                                            child: GestureDetector(
                                              onTap: () {
                                                if (!onyomi.contains(RegExp(r'\.|-'))) {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => KanaDetailPage(onyomi, Yomikata.onyomi)));
                                                }
                                              },
                                              child: Container(
                                                child: Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Text(
                                                      onyomi,
                                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                    )),
                                                decoration: BoxDecoration(
                                                  //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                                                      ),
                                                ),
                                              ),
                                            ))
                                    ],
                                  ),
                                  Divider(),
                                  Wrap(alignment: WrapAlignment.start, direction: Axis.horizontal, children: [
                                    Padding(
                                      padding: EdgeInsets.all(4),
                                      child: FuriganaText(
                                        text: '訓読み',
                                        tokens: [Token(text: '訓読み', furigana: 'くんよみ')],
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    for (var kunyomi in kanji.kunyomi)
                                      Padding(
                                          padding: EdgeInsets.all(4),
                                          child: GestureDetector(
                                            onTap: () {
                                              if (!kunyomi.contains(RegExp(r'\.|-'))) {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => KanaDetailPage(kunyomi, Yomikata.kunyomi)));
                                              }
                                            },
                                            child: Container(
                                              child: Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: Text(
                                                    kunyomi,
                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  )),
                                              decoration: BoxDecoration(
                                                //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                                                color: Colors.white,
                                                borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                                                    ),
                                              ),
                                            ),
                                          )),
                                  ]),
                                  LabelDivider(
                                      child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(children: [
                                            TextSpan(text: 'たんご' + '\n', style: TextStyle(fontSize: 9, color: Colors.white)),
                                            TextSpan(text: '単語', style: TextStyle(fontSize: 18, color: Colors.white))
                                          ]))),
                                  buildCompoundWordColumn(kanji),
                                  LabelDivider(
                                      child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(children: [
                                            TextSpan(text: 'れいぶん' + '\n', style: TextStyle(fontSize: 9, color: Colors.white)),
                                            TextSpan(text: '例文', style: TextStyle(fontSize: 18, color: Colors.white))
                                          ]))),
                                ],
                              ),
                            ))
                      ],
                    );
                  } else {
                    return Container();
                  }
                },
              ),
              StreamBuilder(
                stream: sentenceBloc.sentences,
                builder: (_, AsyncSnapshot<List<Sentence>> snapshot) {
                  if (snapshot.hasData) {
                    var sentences = snapshot.data;
                    var children = <Widget>[];
                    if (sentences.isEmpty) {
                      return Container(
                        height: 200,
                        width: MediaQuery.of(context).size.width,
                        child: Center(
                          child: Text(
                            'No example sentences found _(┐「ε:)_',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    for (var sentence in sentences) {
                      children.add(ListTile(
//                        title: Text(
//                          sentence.text,
//                          style: TextStyle(color: Colors.white),
//                        ),
                        title: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: FuriganaText(
                              text: sentence.text,
                              tokens: sentence.tokens,
                              style: TextStyle(fontSize: 20),
                            )),
                        subtitle: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            sentence.englishText,
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SentenceDetailPage(
                                        sentence: sentence,
                                      )));
                        },
                      ));
                      children.add(Divider(height: 0));
                    }
                    return Column(
                      children: children,
                    );
                  } else {
                    return Container();
                  }
                },
              ),
            ],
          ),
        ));
  }

  Widget buildCompoundWordColumn(Kanji kanji) {
    var children = <Widget>[];
    var onyomiGroup = <Widget>[];
    var kunyomiGroup = <Widget>[];
    var onyomiVerbGroup = <Widget>[];
    var kunyomiVerbGroup = <Widget>[];

    var onyomis = kanji.onyomi;
    var kunyomis = kanji.kunyomi;

    onyomis.sort((left, right) => left.length.compareTo(right.length));
    kunyomis.sort((left, right) => left.length.compareTo(right.length));

    List<Word> onyomiWords = List.from(kanji.onyomiWords);

    for (var onyomi in onyomis) {
      var words = List.from(onyomiWords.where((onyomiWord) => onyomiWord.wordFurigana.contains(onyomi.replaceAll('.', '').replaceAll('-', ''))));
      onyomiWords.removeWhere((word) => words.contains(word));
      var tileTitle = Stack(
        children: <Widget>[
          Positioned.fill(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(4),
                child: Container(
                  child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        onyomi,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )),
                  decoration: BoxDecoration(
                    //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                        ),
                  ),
                ),
              )
            ],
          )),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.white),
              onPressed: () => showCustomBottomSheet(yomi: onyomi, isOnyomi: true),
            ),
          )
        ],
      );

      var tileChildren = <Widget>[];

      for (var word in words) {
        tileChildren.add(ListTile(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WordDetailPage(word: word)));
          },
          onLongPress: () {
            showModalBottomSheet(
                context: context,
                builder: (_) => ListTile(
                      title: Text('Delete from $onyomi'),
                      onTap: () {
                        kanji.onyomiWords.remove(word);
                        kanjiBloc.updateKanji(kanji, isDeleted: true);
                        Navigator.pop(context);
                      },
                    ));
          },
          title: FuriganaText(
            text: word.wordText,
            tokens: [Token(text: word.wordText, furigana: word.wordFurigana)],
            style: TextStyle(fontSize: 24),
          ),
          subtitle: Text(word.meanings, style: TextStyle(color: Colors.white54)),
        ));
        tileChildren.add(Divider(height: 0));
      }

      if (words.isEmpty) {
        tileChildren.add(Container(
          height: 100,
          child: Center(
            child: Text(
              'No compound words found _(┐「ε:)_',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ));
      } else {
        tileChildren.removeLast();
      }

      if (onyomi.contains(RegExp(r'[.-]'))) {
        if (onyomiVerbGroup.isNotEmpty) {
          onyomiVerbGroup.add(Padding(
            padding: EdgeInsets.only(top: 12),
            child: tileTitle,
          ));
        } else {
          onyomiVerbGroup.add(tileTitle);
        }
        onyomiVerbGroup.addAll(tileChildren);
      } else {
        if (onyomiGroup.isNotEmpty) {
          onyomiGroup.add(Padding(
            padding: EdgeInsets.only(top: 12),
            child: tileTitle,
          ));
        } else {
          onyomiGroup.add(tileTitle);
        }
        onyomiGroup.addAll(tileChildren);
      }
    }

    //children.add(SizedBox(height: 12));

    var kunyomiWords = List.from(kanji.kunyomiWords);

    for (var kunyomi in kunyomis) {
      var words = List.from(kunyomiWords.where((kunyomiWord) => kunyomiWord.wordFurigana.contains(kunyomi.replaceAll('.', '').replaceAll('-', ''))));

      kunyomiWords.removeWhere((word) => words.contains(word));

      var tileTitle = Stack(
        children: <Widget>[
          Positioned.fill(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(4),
                child: Container(
                  child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text(
                        kunyomi,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )),
                  decoration: BoxDecoration(
                    //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                        ),
                  ),
                ),
              )
            ],
          )),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.white),
              onPressed: () => showCustomBottomSheet(yomi: kunyomi, isOnyomi: false),
            ),
          )
        ],
      );

      var tileChildren = <Widget>[];

      for (var word in words) {
        tileChildren.add(ListTile(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WordDetailPage(word: word)));
          },
          onLongPress: () {
            showModalBottomSheet(
                context: context,
                builder: (_) => ListTile(
                      title: Text('Delete from $kunyomi'),
                      onTap: () {
                        kanji.kunyomiWords.remove(word);
                        kanjiBloc.updateKanji(kanji, isDeleted: true);
                        Navigator.pop(context);
                      },
                    ));
          },
          title: FuriganaText(
            text: word.wordText,
            tokens: [Token(text: word.wordText, furigana: word.wordFurigana)],
            style: TextStyle(fontSize: 24),
          ),
          subtitle: Text(word.meanings, style: TextStyle(color: Colors.white54)),
        ));
        tileChildren.add(Divider(height: 0));
      }

      if (words.isEmpty) {
        tileChildren.add(Container(
          height: 100,
          child: Center(
            child: Text(
              'No compound words found _(┐「ε:)_',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ));
      } else {
        tileChildren.removeLast();
      }

      if (kunyomi.contains(RegExp(r'[.-]'))) {
        if (kunyomiVerbGroup.isNotEmpty) {
          kunyomiVerbGroup.add(Padding(
            padding: EdgeInsets.only(top: 12),
            child: tileTitle,
          ));
        } else {
          kunyomiVerbGroup.add(tileTitle);
        }
        kunyomiVerbGroup.addAll(tileChildren);
      } else {
        if (kunyomiGroup.isNotEmpty) {
          kunyomiGroup.add(Padding(
            padding: EdgeInsets.only(top: 12),
            child: tileTitle,
          ));
        } else {
          kunyomiGroup.add(tileTitle);
        }
        kunyomiGroup.addAll(tileChildren);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...onyomiGroup,
      ...kunyomiGroup,
      LabelDivider(
          child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(children: [
                TextSpan(text: 'どうし' + '\n', style: TextStyle(fontSize: 9, color: Colors.white)),
                TextSpan(text: '動詞', style: TextStyle(fontSize: 18, color: Colors.white))
              ]))),
      if (onyomiVerbGroup.isEmpty && kunyomiVerbGroup.isEmpty)
        Container(
          height: 100,
          width: MediaQuery.of(context).size.width,
          child: Center(
            child: Text(
              'No related verbs found _(┐「ε:)_',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ...onyomiVerbGroup,
      ...kunyomiVerbGroup,
    ]);
  }

  Widget buildKanjiInfoColumn() {
    return StreamBuilder(
      stream: kanjiBloc.kanji,
      builder: (_, AsyncSnapshot<Kanji> snapshot) {
        if (snapshot.hasData || widget.kanji != null) {
          var kanji = widget.kanji == null ? snapshot.data : widget.kanji;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                children: <Widget>[
                  kanji.jlpt != 0
                      ? Padding(
                          padding: EdgeInsets.all(4),
                          child: Container(
                            child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  'N${kanji.jlpt}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                )),
                            decoration: BoxDecoration(
                              //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                              color: Colors.white,
                              borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                                  ),
                            ),
                          ),
                        )
                      : Container(),
                  GradeChip(
                    grade: kanji.grade,
                  )
                ],
              ),
              Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    "${kanji.strokes} strokes",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )),
            ],
          );
        } else {
          return Container();
        }
      },
    );
  }

  ///show modal bottom sheet where user can add words to onyomi or kunyomi
  void showCustomBottomSheet({String yomi, bool isOnyomi}) {
    var yomiTextEditingController = TextEditingController();
    var wordTextEditingController = TextEditingController();
    var meaningTextEditingController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    CustomBottomSheet.showModalBottomSheet(
        context: context,
        builder: (_) {
          return Container(
            height: 360,
            color: Colors.transparent,
            child: Container(
              height: 360,
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)), color: Theme.of(context).primaryColor),
              child: Form(
                key: formKey,
                autovalidate: false,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            'Add a word to',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Container(
                            child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Text(
                                  yomi,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                )),
                            decoration: BoxDecoration(
                              //boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
                              color: Colors.white,
                              borderRadius: BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          validator: (str) {
                            if (str == null || str.isEmpty) {
                              return "Can't be empty";
                            }
                            return null;
                          },
                          controller: yomiTextEditingController,
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: isOnyomi ? 'Onyomi' : 'Kunyomi',
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25)))),
                          minLines: 1,
                          maxLines: 1,
                        )),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: TextFormField(
                        validator: (str) {
                          if (str == null || str.isEmpty) {
                            return "Can't be empty";
                          }
                          return null;
                        },
                        controller: wordTextEditingController,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Word',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25)))),
                        minLines: 1,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: TextFormField(
                        validator: (str) {
                          if (str == null || str.isEmpty) {
                            return "Can't be empty";
                          }
                          return null;
                        },
                        controller: meaningTextEditingController,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Meaning',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25)))),
                        minLines: 1,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(
                      height: 12,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                          width: MediaQuery.of(context).size.width - 24,
                          height: 42,
                          decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(21))),
                          child: RaisedButton(
                              child: Text('Add'),
                              onPressed: () {
                                if (formKey.currentState.validate()) {
                                  if (isOnyomi) {
                                    kanji.onyomiWords.add(Word(
                                        wordText: wordTextEditingController.text,
                                        wordFurigana: yomiTextEditingController.text,
                                        meanings: meaningTextEditingController.text));
                                  } else {
                                    kanji.kunyomiWords.add(Word(
                                        wordText: wordTextEditingController.text,
                                        wordFurigana: yomiTextEditingController.text,
                                        meanings: meaningTextEditingController.text));
                                  }
                                }
                                kanjiBloc.updateKanji(kanji);
                                Navigator.pop(context);
                                setState(() {});
                              })),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  launchURL(String targetKanji) async {
    final url = Uri.encodeFull('https://en.wiktionary.org/wiki/$targetKanji');

    if (await canLaunch(url)) {
      await launch(url, forceSafariVC: true, forceWebView: true);
    } else {
      throw 'Could not launch $url';
    }
  }
}
