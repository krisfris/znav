// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpx/gpx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';

FlutterTts flutterTts = FlutterTts();

int current_time() {
  var ms = (new DateTime.now()).millisecondsSinceEpoch;
  return (ms / 1000).round();
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = TextStyle(fontSize: 18.0);
  final _saved = Set<WordPair>();

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),
      onTap: () {
        setState(() {
          if (alreadySaved) {
            _saved.remove(pair);
          } else {
            _saved.add(pair);
          }
        });
      }
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return Divider(); /*2*/
  
          final index = i ~/ 2; /*3*/
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10)); /*4*/
          }
          return _buildRow(_suggestions[index]);
        });
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final tiles = _saved.map(
            (WordPair pair) {
              return ListTile(
                title: Text(
                  pair.asPascalCase,
                  style: _biggerFont,
                ),
              );
            },
          );
          final divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
        ],
      ),
      body: _buildSuggestions(),
    );
  }
}

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Center(
        child: RaisedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Go back'),
        ),
      ),
    );
  }
}


class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

String heading_to_cardinal_direction (double heading) {
    if (heading >= 292.5 && heading <= 337.5) {
      return 'north';
    } else if (heading >= 22.5 && heading <= 67.5) {
      return 'northeast';
    } else if (heading >= 67.5 && heading <= 112.5) {
      return 'east';
    } else if (heading >= 112.5 && heading <= 157.5) {
      return 'southeast';
    } else if (heading >= 157.5 && heading <= 202.5) {
      return 'south';
    } else if (heading >= 202.5 && heading <= 247.5) {
      return 'southwest';
    } else if (heading >= 247.5 && heading <= 292.5) {
      return 'west';
    } else {
      return 'north';
    }
}

class _HomeState extends State<Home> {
  TextEditingController _controller;
  bool _navigating = false;
  StreamSubscription<Position> positionStream;
  double lon, lat;
  List<Wpt> _points = [];
  int last_announcement = current_time();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void update () {
    Wpt closest;
    double min_d;
    _points.forEach((pt) {
        final d = distanceBetween(lat, lon, pt.lat, pt.lon);
        if (min_d == null || d < min_d) {
         min_d = d;
         closest = pt;
        }
    });
    print('closest point is ${closest} with distance ${min_d}');
    double bearing = bearingBetween(lat, lon, closest.lat, closest.lon);
    double heading = (bearing >= 0) ? bearing : 360.0 + bearing;
    String direction = heading_to_cardinal_direction(heading);
    print('heading is ${heading}, direction ${heading_to_cardinal_direction(heading)}');

    final now = current_time();
    if (min_d > 30) {
      flutterTts.speak('head ${direction}, distance ${min_d.round()}');
      last_announcement = now;
    }
  }

  void start_navigation () async {
    positionStream = getPositionStream(distanceFilter: 12).listen(
      (Position position) {
        setState(() {
          lat = position.latitude;
          lon = position.longitude;
        });
        update();
    });

    await FlutterForegroundPlugin.startForegroundService(
      holdWakeLock: false,
      onStarted: () {
        print("Foreground on Started");
      },
      onStopped: () {
        print("Foreground on Stopped");
      },
      title: "Flutter Foreground Service",
      content: "This is Content",
      iconName: "ic_stat_hot_tub",
    );

    setState(() { _navigating = true; });
    //flutterTts.speak('navigation started');
  }

  void stop_navigation ()  async {
    positionStream.cancel();
    await FlutterForegroundPlugin.stopForegroundService();
    setState(() { _navigating = false; });
    //flutterTts.speak('navigation stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ZNAV'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    readOnly: true,
                  )
                ),
                RaisedButton(
                  onPressed: () async {

                    FilePickerResult result = await FilePicker.platform.pickFiles();
                    if(result != null) {
                       File file = File(result.files.single.path);
                       String contents = await file.readAsString();
                       var gpx = GpxReader().fromString(contents);
                       print(gpx.trks[0].trksegs[0].trkpts[0].lat);
                       gpx.trks[0].trksegs.forEach((trkseg) {
                         trkseg.trkpts.forEach((pt) {
                            _points.add(pt);
                         });
                       });

                    }
                  },
                  child: Text('Open GPX')
                ),
              ]
            ),
            margin: EdgeInsets.only(bottom: 15.0, top: 15.0)
          ),
          Text('Longitude: ${lon.toString()}'),
          Text('Latitude: ${lat.toString()}'),
        ]
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_navigating) {
            await stop_navigation();
          } else {
            await start_navigation();
          }
        },
        child: Icon(_navigating ? Icons.pause : Icons.navigation),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZNAV',
      theme: ThemeData(
        primaryColor: Colors.green,
      ),
      home: Home(),
    );
  }
}

//void startForegroundService() async {
//  await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 5);
//  await FlutterForegroundPlugin.setServiceMethod(globalForegroundService);
//
//}
//
//void globalForegroundService() {
//  debugPrint("current datetime is ${DateTime.now()}");
//}

void main() {
  runApp(MyApp());
//  startForegroundService();
// await FlutterForegroundPlugin.stopForegroundService();
}

