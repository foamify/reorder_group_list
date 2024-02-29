import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const MainApp());
}

//TODO: scroll at top/bottom https://www.technicalfeeder.com/2021/09/flutter-scrolling-while-dragging-an-item/

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

final _scrollViewKey = GlobalKey();
final _scroller = ScrollController();

class _MainAppState extends State<MainApp> {
  final elements = ValueNotifier<List<Element>>([]);

  @override
  void initState() {
    elements.value = List.generate(
      50,
      (index) => switch (index) {
        _ when index % 4 == 0 => Element('element $index', null, [
            Element('child $index', 'element $index',
                [Element('grandchild $index', 'child $index')]),
          ]),
        _ when index % 4 == 1 => Element('element $index', null, [
            Element('child $index', 'element $index'),
          ]),
        _ => Element('element $index', null)
      },
    );
    super.initState();
  }

  var _timerMove = Timer(Duration.zero, () {});
  bool? isMoveUp = false;
  bool isDragging = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.blueGrey,
        body: Container(
          margin: const EdgeInsets.symmetric(
            vertical: 64,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            controller: _scroller,
            key: _scrollViewKey,
            child: Listener(
              onPointerMove: (event) {
                if (!isDragging) {
                  _timerMove.cancel();
                  isMoveUp = null;
                  return;
                }
                ;
                const moveDistance = 3;
                const detectedRange = 100;

                final scrollView = _scrollViewKey.currentContext
                    ?.findRenderObject() as RenderBox?;
                if (scrollView != null) {
                  final topY = scrollView.localToGlobal(Offset.zero).dy;
                  final bottomY = topY + scrollView.size.height;
                  if (event.position.dy < topY + detectedRange) {
                    isMoveUp = true;
                    _timerMove.cancel();
                    void move() {
                      if (_scroller.offset <= 0) {
                        _scroller.jumpTo(-moveDistance.toDouble());
                        return;
                      }
                      _scroller.jumpTo(_scroller.offset -
                          moveDistance -
                          max(0, topY - event.position.dy));
                    }

                    move();
                    _timerMove = Timer.periodic(Durations.short1, (timer) {
                      move();
                    });
                  } else if (event.position.dy > bottomY - detectedRange) {
                    isMoveUp = false;
                    _timerMove.cancel();
                    void move() {
                      if (_scroller.offset >=
                          _scroller.position.maxScrollExtent) {
                        _scroller.jumpTo(
                          _scroller.position.maxScrollExtent + moveDistance,
                        );
                        return;
                      }
                      _scroller.jumpTo(_scroller.offset +
                          moveDistance +
                          max(0, event.position.dy - bottomY));
                    }

                    move();
                    _timerMove = Timer.periodic(Durations.short1, (timer) {
                      move();
                    });
                  } else {
                    _timerMove.cancel();
                    isMoveUp = null;
                  }
                }
              },
              onPointerCancel: (event) {
                setState(() {
                  isDragging = false;
                });
                _timerMove.cancel();
                isMoveUp = null;
              },
              onPointerUp: (event) {
                setState(() {
                  isDragging = false;
                });
                _timerMove.cancel();
                isMoveUp = null;
              },
              child: ValueListenableBuilder(
                  valueListenable: elements,
                  builder: (context, elementsValue, _) {
                    return ElementTree(
                      elementsValue,
                      onDrag: () => setState(() {
                        isDragging = true;
                      }),
                      onReorder: (element, targetId, position) {
                        if (element.id == targetId) return;

                        //
                        final newElements = [...elementsValue];
                        void deleteElement() {
                          for (int i = 0; i < newElements.length; i++) {
                            if (newElements[i].id == element.id) {
                              newElements.removeAt(i);
                            } else {
                              newElements[i].removeId(element.id);
                            }
                          }
                        }

                        //
                        if (position == DragAlign.center) {
                          print('newparent');
                          for (int i = 0; i < newElements.length; i++) {
                            if (newElements[i].insertChild(
                                targetId, element, deleteElement)) {
                              break;
                            }
                          }
                        } else {
                          print('newsibling');
                          if (newElements
                              .any((element) => element.id == targetId)) {
                            final targetIndex = newElements.indexWhere(
                              (element) => element.id == targetId,
                            );
                            if (position == DragAlign.top) {
                              newElements.insert(targetIndex, element);
                            } else if (position == DragAlign.bottom) {
                              newElements.insert(targetIndex + 1, element);
                            }
                          } else {
                            for (int i = 0; i < newElements.length; i++) {
                              print('target not found');
                              newElements[i].insertSibling(
                                  targetId, element, position, deleteElement);
                            }
                          }
                        }
                        //

                        elements.value.clear();
                        elements.value = [...newElements];
                      },
                    );
                  }),
            ),
          ),
        ),
      ),
    );
  }
}

class Element {
  Element(this.id, this.parentId, [List<Element>? children])
      : children = children ?? [];
  final String id;
  String? parentId;
  List<Element> children;

  void removeId(String id) {
    if (children.any((element) => element.id == id)) {
      children.removeWhere((element) => element.id == id);
    } else {
      for (var element in children) {
        element.removeId(id);
      }
    }
  }

  bool insertChild(String targetId, Element element, Function deleteElement) {
    if (id == element.id || parentId == element.id) {
      return false;
    }
    print('Inserting child with id: $targetId and element id: ${element.id}');
    element.parentId = targetId;
    if (id == targetId) {
      print('Setting parent for element with id: ${element.id}');
      deleteElement();
      children.add(element);
      return true;
    }
    if (children.any((element) => element.id == targetId)) {
      deleteElement();
      final newParentIndex =
          children.indexWhere((element) => element.id == targetId);
      final newParent = children[newParentIndex];
      newParent.children.add(element);
      children[newParentIndex] = newParent;
      return true;
    }
    for (final child in children) {
      if (child.insertChild(targetId, element, deleteElement)) {
        return true;
      }
    }
    return false;
  }

  bool insertSibling(String targetId, Element element, DragAlign position,
      Function deleteElement) {
    if (id == element.id || parentId == element.id) {
      return false;
    }
    if (children.any((element) => element.id == targetId)) {
      deleteElement();
      final siblingIndex =
          children.indexWhere((element) => element.id == targetId);
      element.parentId = targetId;
      if (position == DragAlign.top) {
        children.insert(siblingIndex, element);
      } else {
        children.insert(siblingIndex + 1, element);
      }
      return true;
    } else {
      for (final child in children) {
        if (child.insertSibling(targetId, element, position, deleteElement)) {
          return true;
        }
      }
    }
    return false;
  }
}

class ElementTree extends StatelessWidget {
  const ElementTree(this.elements,
      {super.key, required this.onReorder, required this.onDrag});

  final List<Element> elements;
  final void Function(
    Element element,
    String targetId,
    DragAlign position,
  ) onReorder;
  final void Function() onDrag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: elements
          .map(
            (element) => ElementWidget(
              element,
              onReorder: onReorder,
              onDrag: onDrag,
            ),
          )
          .toList(),
    );
  }
}

class ElementWidget extends StatefulWidget {
  const ElementWidget(this.element,
      {super.key, required this.onReorder, required this.onDrag});

  final Element element;
  final void Function(
    Element element,
    String targetId,
    DragAlign position,
  ) onReorder;
  final void Function() onDrag;

  @override
  State<ElementWidget> createState() => _ElementWidgetState();
}

enum DragAlign {
  top,
  bottom,
  center,
  none,
}

class _ElementWidgetState extends State<ElementWidget> {
  var widgetOffset = Offset.zero;
  var widgetSize = Size.zero;

  var position = DragAlign.none;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: TopBottomLinePainter(
              isTop: switch (position) {
            DragAlign.top => true,
            DragAlign.bottom => false,
            _ => null,
          }),
          child: DragTarget<Element>(
              onMove: (details) {
                widget.onDrag();
                setState(() {
                  position = switch (details.offset.dy) {
                    _
                        when details.offset.dy <=
                            widgetOffset.dy + widgetSize.height / 4 =>
                      DragAlign.top,
                    _
                        when details.offset.dy >=
                            widgetOffset.dy + 3 * widgetSize.height / 4 =>
                      DragAlign.bottom,
                    _ => DragAlign.center,
                  };
                });
              },
              onLeave: (data) => setState(() {
                    position = DragAlign.none;
                  }),
              onAcceptWithDetails: (details) {
                widget.onReorder(
                  details.data,
                  widget.element.id,
                  position,
                );
                setState(() {
                  position = DragAlign.none;
                });
              },
              builder: (context, candidateData, rejectedData) {
                final renderBox = context.findRenderObject() as RenderBox?;
                widgetOffset =
                    renderBox?.localToGlobal(Offset.zero) ?? widgetOffset;
                widgetSize = renderBox?.size ?? widgetSize;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    border: position == DragAlign.center
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                  ),
                  position: DecorationPosition.foreground,
                  child: Draggable<Element>(
                    data: widget.element,
                    feedback: const SizedBox.shrink(),
                    dragAnchorStrategy: (draggable, context, position) =>
                        pointerDragAnchorStrategy(draggable, context, position),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      margin: const EdgeInsets.all(8),
                      child: Text(widget.element.id),
                    ),
                  ),
                );
              }),
        ),
        ...widget.element.children.map(
          (element) => Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ElementWidget(
              element,
              onReorder: widget.onReorder,
              onDrag: widget.onDrag,
            ),
          ),
        ),
      ],
    );
  }
}

class TopBottomLinePainter extends CustomPainter {
  TopBottomLinePainter({super.repaint, required this.isTop});
  final bool? isTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (isTop == null) {
      return;
    }
    final paint = Paint()
          //
          ..color = Colors.lightGreen
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
        //
        ;
    if (isTop!) {
      canvas.drawLine(
        const Offset(0, 0),
        Offset(size.width, 0),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
