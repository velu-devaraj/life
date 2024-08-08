import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life/bridge.dart';
import 'package:life/life.dart';
import 'package:life/life_app_state.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const Color darkBlue = Color.fromARGB(255, 18, 32, 47);

void main() {
  final log = Logger();
  final Key lifeAppWidgetKey = GlobalKey();
  LifeAppWidget lifeAppWidget = LifeAppWidget(key: lifeAppWidgetKey);
  runApp(lifeAppWidget);

  log.i("main() finished");
}

// ignore: must_be_immutable
class LifeAppWidget extends StatelessWidget {
  static final log = Logger();
  LifeGridPainter? lifeGridPainter;
  GestureDetector? gestureDetector;
  GridWidgetState? gridWidgetState;
  List<List<bool>>? canvasCells;

  final GlobalKey lifeAppWidgetKey = GlobalKey();
  final GlobalKey gestureDetectorKey = GlobalKey();

  LifeAppWidget({required Key key}) : super(key: key) {
    lifeGridPainter = LifeGridPainter();
    gestureDetector = GestureDetector(
        key: gestureDetectorKey,
        onDoubleTapDown: (details) {
          log.i(details.localPosition);

          if (null == rowCount || null == columnCount) {
            return;
          } else {
            canvasCells ??= initAsLifeless();
          }

          gridWidgetState!.update(canvasCells!);
          log.i(gestureDetectorKey.currentContext!.size);

          // gestureDetector.child.
          int col = details.localPosition.dx.round();
          int row = details.localPosition.dy.round();

          var rec = localPositionToCellID(
              details.localPosition, gestureDetectorKey.currentContext!.size);

          gridWidgetState!.updateCell(rec.$1, rec.$2);
        },
        child: CustomPaint(painter: lifeGridPainter));
    gridWidgetState = GridWidgetState(lifeGridPainter!, gestureDetector!);
    gw = GridWidget(
        key: UniqueKey(),
        gridWidgetState: gridWidgetState,
        gestureDetector: gestureDetector!);
  }

  (int, int) localPositionToCellID(Offset offset, Size? canvasSize) {
    double renderedXSize = 25.0 * columnCount!;
    double renderedYSize = 25.0 * rowCount!;
    double xStart = (canvasSize!.width - renderedXSize) / 2;
    double yStart = (canvasSize.height - renderedYSize) / 2;
    int col = ((offset.dy - yStart) / 25).floor();
    int row = ((offset.dx - xStart) / 25).floor();

    return (row, col);
  }

  List<List<bool>> initAsLifeless() {
    List<List<bool>> newCells = List.empty(growable: true);
    for (int i = 0; i < columnCount!; i++) {
      newCells.add(List.empty(growable: true));
      for (int j = 0; j < rowCount!; j++) {
        newCells[i].add(false);
      }
    }
    return newCells;
  }

  Bridge<Life>? lifeInterface;

  CustomPaint? cp;
  GridWidget? gw;
  int messageCount = 0;
  bool isRunning = false;

  int? rowCount;
  int? columnCount;

  int? generateMilliSec;

  LifeAppState laState = LifeAppState();
  ReceivePort lifeReceivePort = ReceivePort();
  late SendPort lifeSendPort;
  late GestureDetector gd;

  bool? withRandomCells;

  void newCellsgenerated(List<List<bool>> cells) {
    gw!.gridWidgetState!.update(cells);
  }

  Widget buildMaterialApp() {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: darkBlue),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Life'),
        ),
        body: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
            child: Column(
              children: <Widget>[
                Expanded(
                    child: LayoutBuilder(
                  builder: (_, constraints) => Container(
                      width: constraints.widthConstraints().maxWidth,
                      height: constraints.heightConstraints().maxHeight,
                      color: const Color.fromARGB(255, 218, 238, 195),
                      child: gw),
                )),
                SizedBox(
                    height: 150,
                    //  width: 600 ,
                    child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: false,
                        primary: true,
                        childAspectRatio: 4,
                        padding: const EdgeInsets.all(2),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 5,
                        crossAxisCount: 6,
                        children: <Widget>[
                          TextField(
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                  labelText: "Enter rows"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                laState.rowSet = true;
                                rowCount = int.parse(value);
                                
                              }),
                          TextField(
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                  labelText: "Enter columns"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                laState.columnSet = true;
                                columnCount = int.parse(value);
                              }),
                          TextField(
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                  labelText: "Enter delay in millisec"),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (value) {
                                laState.genTimeSet = true;
                                generateMilliSec = int.parse(value);
                              }),
                          SizedBox(
                              width: 75,
                              height: 50,
                              child: ElevatedButton(
                                style: style,
                                onPressed: () {
                                  if (laState.canStart()) {
                                    laState.isRunning = true;
                                    withRandomCells = true;
                                    lifeInterface = Bridge.fromList(
                                        Life.withList,
                                        [
                                          columnCount,
                                          rowCount,
                                          generateMilliSec
                                        ],
                                        newCellsgenerated,
                                        kIsWeb ? false : true);
                                    lifeInterface!
                                        .callDelegateFromList(["start"]);
                                  }
                                },
                                child: const Text('Start Random'),
                              )),
                          SizedBox(
                              width: 75,
                              height: 50,
                              child: ElevatedButton(
                                style: style,
                                onPressed: () {
                                  if (laState.canStart()) {
                                    if (null == lifeInterface) {
                                      withRandomCells = false;
                                      lifeInterface = Bridge.fromList(
                                          Life.withList,
                                          [
                                            lifeGridPainter!.receivedCells,
                                            generateMilliSec
                                          ],
                                          newCellsgenerated,
                                          kIsWeb ? false : true);
                                      lifeInterface!
                                          .callDelegateFromList(["start"]);
                                      laState.isRunning = true;
                                    } else {
                                      lifeInterface!
                                          .callDelegateFromList(["start"]);
                                      laState.isRunning = true;
                                    }
                                  }
                                },
                                child: const Text('Start'),
                              )),
                          SizedBox(
                              width: 75,
                              height: 50,
                              child: ElevatedButton(
                                style: style,
                                onPressed: () {
                                  if (laState.isRunning) {
                                    laState.isRunning = false;
                                    lifeInterface!
                                        .callDelegateFromList(["stop"]);
                                  }
                                },
                                child: const Text('Stop'),
                              )),
                        ]))
              ],
            )),
      ),
    );
  }

  final ButtonStyle style = ElevatedButton.styleFrom(
      textStyle: const TextStyle(fontSize: 10),
      shape: const LinearBorder(
        side: BorderSide(color: Colors.blue),
        bottom: LinearBorderEdge(),
      ),
      fixedSize: const Size(60, 25));

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    gd = GestureDetector(
        onDoubleTapDown: (details) {
          log.d(details.localPosition);
        },
        child: CustomPaint(painter: lifeGridPainter));

    final ButtonStyle style = ElevatedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 10),
        shape: const LinearBorder(
          side: BorderSide(color: Colors.blue),
          bottom: LinearBorderEdge(),
        ),
        fixedSize: const Size(60, 25));

    return buildMaterialApp();
  }
}

class GridWidget extends StatefulWidget {
  GridWidget(
      {required Key key,
      required this.gridWidgetState,
      required this.gestureDetector})
      : super(key: key);

  GridWidgetState? gridWidgetState;
  GestureDetector gestureDetector;
  final log = Logger();

  @override
  // ignore: no_logic_in_create_state
  State<StatefulWidget> createState() {
    log.i("createState called");
    return gridWidgetState!;
  }
}

class GridWidgetState extends State<StatefulWidget> {
  final log = Logger();
  LifeGridPainter lifeGridPainter;
  GestureDetector gd;

  GridWidgetState(this.lifeGridPainter, this.gd);

  void update(List<List<bool>> newCells) {
    lifeGridPainter.receivedCells = newCells;

    log.i("update called");
    lifeGridPainter.notifyListeners();
  }

  void updateCell(int i, int j) {
    log.d("updateCell called");
    if (i < 0 || i >= lifeGridPainter.receivedCells!.length) {
      return;
    }
    if (j < 0 || j >= lifeGridPainter.receivedCells![0].length) {
      return;
    }
    lifeGridPainter.receivedCells![i][j] =
        !lifeGridPainter.receivedCells![i][j];

    log.d("updateCell called");
    lifeGridPainter.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return gd;
  }
}

class LifeGridPainter extends ChangeNotifier implements CustomPainter {
   final log = Logger();
  LifeGridPainter() {
    receivedCells = List.empty(growable: true);
  }

  late List<List<bool>>? receivedCells;

  @override
  void paint(Canvas canvas, Size size) {
    log.d("Calling paint ");
    // Define a paint object
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Colors.indigo;

    final paintDead = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Colors.black26;

    const double rSize = 25.0;

    if (receivedCells == null || receivedCells!.isEmpty) {
      return;
    }

    int m = receivedCells!.length;
    int n = receivedCells![0].length;

    double xStart = (size.width - rSize * m) / 2;
    double yStart = (size.height - rSize * n) / 2;

    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  xStart + (rSize * i), yStart + (rSize * j), rSize, rSize),
              const Radius.circular(3)),
          getCellValue(receivedCells, i, j) ? paint : paintDead,
        );
      }
    }
  }

  bool getCellValue(List<List<bool>>? inCells, int i, int j) {
    if (inCells == null) {
      log.d("null cells");
      return false;
    }
    return inCells[i][j];
  }

  @override
  bool shouldRepaint(LifeGridPainter oldDelegate) => true;

  @override
  bool get hasListeners => true;

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  @override
  bool? hitTest(Offset position) => true;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) {
    return true;
  }
}
