import 'dart:html';
import "dart:typed_data";

import 'package:LoaderLib/Loader.dart';
import "package:path/path.dart" as Path;

Future<void> main() async {
    final List<IconGroup> iconGroups = <IconGroup>[
        new IconGroup("Resource", <IconType>[
            new IconType("Cost Add", "mod_X_cost_add", const Point<int>(12,9), 1, foregrounds: <String>["cost","resource_add"]),
            new IconType("Cost Mult", "mod_X_cost_mult", const Point<int>(12,9), 1, foregrounds: <String>["cost","mult"]),
            new IconType("Produces Add", "mod_X_produces_add", const Point<int>(16,10), 1, foreground: "resource_add", background: "produces_bg"),
            new IconType("Produces Mult", "mod_X_produces_mult", const Point<int>(16,11), 1, foreground: "mult", background: "produces_bg"),
            new IconType("Upkeep Add", "mod_X_upkeep_add", const Point<int>(8,12), 1, foregrounds: <String>["upkeep","resource_add"], fgOffset: const Point<int>(0,-2)),
            new IconType("Upkeep Mult", "mod_X_upkeep_mult", const Point<int>(8,12), 1, foregrounds: <String>["upkeep","mult"]),
            new IconType("Resource Add", "mod_resource_X_add", const Point<int>(10,11), 1, foreground: "resource_add"),
            new IconType("Resource Mult", "mod_resource_X_mult", const Point<int>(10,11), 1, foreground: "mult2", fgOffset: const Point<int>(0,-1)),
            new IconType("Mines Max", "mod_building_X_mines_max", const Point<num>(6,6), 0.63, background: "mines_max")..warning="This auto-generated name is probably incorrect",
        ]),
        new IconGroup("District", <IconType>[
            new IconType("Build Cap", "mod_X_max", const Point<int>(13,12), 23/77, foreground: "max"),
        ]),
        new IconGroup("Job", <IconType>[
            new IconType("Add", "mod_X_add", const Point<num>(12.35,11.1), 0.82, foreground: "job_add"),
        ]),
    ];

    final Element inputBox = document.getElementById("input")!;
    final TextInputElement inputName = document.getElementById("name")! as TextInputElement;
    final Element previewBox = document.getElementById("preview")!;
    final Element outputBox = document.getElementById("output")!;

    String? prevBlobUrl;

    // set up output canvases
    final Map<IconType, CanvasElement> canvases = <IconType,CanvasElement>{};
    for (final IconGroup group in iconGroups) {
        final Element groupDiv = new DivElement()..className="group"
            ..append(new HeadingElement.h1()..text = group.name)
            ..append(new ButtonElement()..text="Render"..onClick.listen((Event event) {
                group.processIcons(canvases);
            }))
        ;

        for (final Icon icon in group.icons) {
            final Element div = new DivElement()
                ..className = "iconType";
            div.append(new SpanElement()..text = icon.iconType.name);

            final CanvasElement canvas = new CanvasElement(width: 25, height: 25);
            div.append(canvas);

            icon.canvas = canvas;

            final Element name = new SpanElement();
            icon.text = name;
            div.append(name);

            div.append(FileFormat.saveButton(Formats.png, () async {
                if (prevBlobUrl != null) {
                    Url.revokeObjectUrl(prevBlobUrl!);
                }
                final Blob blob = await canvas.toBlob("image/png");
                final String url = Url.createObjectUrlFromBlob(blob);

                prevBlobUrl = url;

                return Formats.png.requestObjectFromUrl(url);
            }, caption: "Save", filename: () => icon.name.isEmpty ? "file" : icon.name));

            groupDiv.append(div);
        }

        // TODO: save all button

        outputBox.append(groupDiv);
    }

    // set up load button
    final Element input = FileFormat.loadButton(Formats.png, (ImageElement img, String filename) {
        previewBox.children.clear();
        previewBox.append(img);

        inputName.value = Path.basenameWithoutExtension(filename);

        for (final IconGroup group in iconGroups) {
            group.image = img;
            group.imageName = inputName.value;
        }

    }, accept: <String>{"image/png"});
    inputBox.append(input);

}

Future<void> process(ImageElement input, String name, Icon icon) async {
    final CanvasElement canvas = icon.canvas;
    final IconType iconType = icon.iconType;
    final CanvasRenderingContext2D ctx = canvas.context2D;

    final num width = input.width! * iconType.iconScale;
    final num height = input.height! * iconType.iconScale;
    final num x = iconType.iconPos.x - width * 0.5;
    final num y = iconType.iconPos.y - height * 0.5;

    ctx.clearRect(0,0,canvas.width!,canvas.height!);

    for (int i=0; i < iconType.backgroundUrls.length; i++) {
        final String background = iconType.backgroundUrls[i];
        final ImageElement bg = await Loader.getResource("images/$background.png");

        if (iconType.backgroundOffsets.length > i && iconType.backgroundOffsets[i] != null) {
            final Point<int> o = iconType.backgroundOffsets[i]!;
            ctx.drawImage(bg, o.x, o.y);
        } else {
            ctx.drawImage(bg, 0, 0);
        }
    }

    ctx.drawImageScaled(input, x, y, width, height);

    for (int i=0; i < iconType.foregroundUrls.length; i++) {
        final String foreground = iconType.foregroundUrls[i];
        final ImageElement fg = await Loader.getResource("images/$foreground.png");

        if (iconType.foregroundOffsets.length > i && iconType.foregroundOffsets[i] != null) {
            final Point<int> o = iconType.foregroundOffsets[i]!;
            ctx.drawImage(fg, o.x, o.y);
        } else {
            ctx.drawImage(fg, 0, 0);
        }
    }

    icon.rendered = true;
    icon.name = "${iconType.fileName.replaceFirst("X", name)}.png";
    icon.text.text = icon.name;
}

class IconType {
    final String name;
    final String fileName;
    final Point<num> iconPos;
    final num iconScale;
    final List<String> backgroundUrls = <String>[];
    final List<String> foregroundUrls = <String>[];
    final List<Point<int>?> backgroundOffsets = <Point<int>?>[];
    final List<Point<int>?> foregroundOffsets = <Point<int>?>[];

    String? warning;

    IconType(String this.name, String this.fileName, Point<num> this.iconPos, num this.iconScale, {String? foreground, List<String>? foregrounds, Point<int>? fgOffset, List<Point<int>?>? fgOffsets, String? background, List<String>? backgrounds, Point<int>? bgOffset, List<Point<int>?>? bgOffsets}) {
        if (foreground != null) {
            foregroundUrls.add(foreground);
        } else if (foregrounds != null) {
            foregroundUrls.addAll(foregrounds);
        }
        if (fgOffset != null) {
            foregroundOffsets.add(fgOffset);
        } else if (fgOffsets != null) {
            foregroundOffsets.addAll(fgOffsets);
        }

        if (background != null) {
            backgroundUrls.add(background);
        } else if (backgrounds != null) {
            backgroundUrls.addAll(backgrounds);
        }
        if (bgOffset != null) {
            backgroundOffsets.add(bgOffset);
        } else if (bgOffsets != null) {
            backgroundOffsets.addAll(bgOffsets);
        }
    }
}

class Icon {
    final IconType iconType;
    late final CanvasElement canvas;
    late final Element text;
    String name = "";

    bool rendered = false;

    Icon(IconType this.iconType);
}

class IconGroup {
    final String name;
    final List<Icon> icons = <Icon>[];

    ImageElement? image;
    String? imageName;

    IconGroup(String this.name, List<IconType> iconTypes) {
        for (final IconType iconType in iconTypes) {
            icons.add(new Icon(iconType));
        }
    }

    void processIcons(Map<IconType, CanvasElement> canvases) {
        if (image == null) { return; }

        for (final Icon icon in icons) {
            process(image!, imageName!, icon);
        }
    }
}