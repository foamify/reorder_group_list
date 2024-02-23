import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

//TODO: scroll at top/bottom https://www.technicalfeeder.com/2021/09/flutter-scrolling-while-dragging-an-item/

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.blueGrey,
        body: SingleChildScrollView(
          child: ValueListenableBuilder(
              valueListenable: elements,
              builder: (context, elementsValue, _) {
                return ElementTree(
                  elementsValue,
                  onReorder: (element, targetId, position) {
                    if (element.id == targetId) return;

                    //
                    final newElements = [...elementsValue];
                    for (int i = 0; i < newElements.length; i++) {
                      if (newElements[i].id == element.id) {
                        newElements.removeAt(i);
                      } else {
                        newElements[i].removeId(element.id);
                      }
                    }
                    //
                    if (position == DragAlign.center) {
                      print('newparent');
                      for (int i = 0; i < newElements.length; i++) {
                        if (newElements[i].insertChild(targetId, element)) {
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
                          newElements[i]
                              .insertSibling(targetId, element, position);
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

  bool insertChild(String targetId, Element element) {
    print('Inserting child with id: $targetId and element id: ${element.id}');
    element.parentId = targetId;
    if (id == targetId) {
      print('Setting parent for element with id: ${element.id}');
      children.add(element);
      return true;
    }
    if (children.any((element) => element.id == targetId)) {
      final newParentIndex =
          children.indexWhere((element) => element.id == targetId);
      final newParent = children[newParentIndex];
      newParent.children.add(element);
      children[newParentIndex] = newParent;
      return true;
    }
    for (final child in children) {
      if (child.insertChild(targetId, element)) {
        return true;
      }
    }
    return false;
  }

  bool insertSibling(String targetId, Element element, DragAlign position) {
    if (children.any((element) => element.id == targetId)) {
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
        if (child.insertSibling(targetId, element, position)) {
          return true;
        }
      }
    }
    return false;
  }
}

class ElementTree extends StatelessWidget {
  const ElementTree(this.elements, {super.key, required this.onReorder});

  final List<Element> elements;
  final void Function(
    Element element,
    String targetId,
    DragAlign position,
  ) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: elements
          .map(
            (element) => ElementWidget(
              element,
              onReorder: onReorder,
            ),
          )
          .toList(),
    );
  }
}

class ElementWidget extends StatefulWidget {
  const ElementWidget(this.element, {super.key, required this.onReorder});

  final Element element;
  final void Function(
    Element element,
    String targetId,
    DragAlign position,
  ) onReorder;

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
        DragTarget<Element>(
            onMove: (details) => setState(() {
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
                }),
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
                      : Border(
                          top: BorderSide(
                              width: 2,
                              color: position == DragAlign.top
                                  ? Colors.red
                                  : Colors.transparent),
                          bottom: BorderSide(
                            width: 2,
                            color: position == DragAlign.bottom
                                ? Colors.red
                                : Colors.transparent,
                          )),
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
                    margin: const EdgeInsets.all(1),
                    child: Text(widget.element.id),
                  ),
                ),
              );
            }),
        ...widget.element.children.map(
          (element) => Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ElementWidget(
              element,
              onReorder: widget.onReorder,
            ),
          ),
        ),
      ],
    );
  }
}
