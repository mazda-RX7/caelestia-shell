pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property Brightness.Monitor monitor
    required property DrawerVisibilities visibilities

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    // ── State ────────────────────────────────────────────────────────────────
    property bool submenuOpen: false

    property int  blurSize:         12
    property int  blurPasses:       4
    property int  crtScanIntensity: 35
    property int  crtVigStrength:   70
    property bool crtScanEnabled:   true
    property bool crtVigEnabled:    true
    property real crtScanSize:      2.0
    property bool kbdBacklightOn:   false
    property int  crtBloomStrength: 15
    property bool crtBloomEnabled:  true
    property int  crtChromOffset:   3
    property bool crtChromEnabled:  true
    property int  crtCurvAmount:    10

    // "none" | "crt" | "backlit" | "frontlit"
    property string shaderMode: "crt"

    // LCD shared params (both backlit and frontlit)
    property real lcdPitch:    6.0
    property bool lcdEnabled:  true
    property real lcdGap:      2.0
    property int  lcdRound:    10
    property int  lcdBright:   100
    property int  lcdVigStr:   0
    property int  lcdIntensity: 100

    // Frontlit-only params
    property int  lcdGapLight:   30   // 0–50 % — ambient from reflector
    property int  lcdShadowStr:  0    // 0–100 % — how much cells shadow the gap
    property real lcdShadowDist: 2.0  // 1–8 px — pixel layer height above reflector

    // ── Theme-aware color helpers ─────────────────────────────────────────────
    readonly property color clrFg:         Colours.palette.m3onSurface
    readonly property color clrFgVariant:  Colours.palette.m3onSurfaceVariant
    readonly property color clrOutline:    Colours.palette.m3outline
    readonly property color clrOutlineVar: Colours.palette.m3outlineVariant

    // ── Layout constants ─────────────────────────────────────────────────────
    readonly property real padL:   Tokens.padding.large
    readonly property real arrowW: 24

    implicitWidth:  mainSection.width + arrowW + (submenuOpen ? subPanel.targetW : 0) + padL
    implicitHeight: Math.max(mainLayout.implicitHeight,
                             submenuOpen ? subLayout.implicitHeight : 0) + padL * 2

    Behavior on implicitWidth  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // ── Shader debounce timers ────────────────────────────────────────────────
    Timer {
        id: shaderApplyTimer
        interval: 100
        onTriggered: Quickshell.execDetached(["crt-shader", "apply"])
    }
    Timer {
        id: lcdApplyTimer
        interval: 100
        onTriggered: Quickshell.execDetached(["lcd-shader", "apply"])
    }

    // ── Blur init ────────────────────────────────────────────────────────────
    Process {
        running: true
        command: ["hyprctl", "getoption", "decoration:blur:size", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.blurSize = JSON.parse(text).int; } catch(e) {} }
        }
    }
    Process {
        running: true
        command: ["hyprctl", "getoption", "decoration:blur:passes", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.blurPasses = JSON.parse(text).int; } catch(e) {} }
        }
    }

    // ── CRT init ────────────────────────────────────────────────────────────
    Process {
        running: true
        command: ["crt-shader", "get", "scanlines", "intensity"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.crtScanIntensity = v; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "vignette", "strength"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.crtVigStrength = v; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "scanlines", "enabled"]
        stdout: StdioCollector {
            onStreamFinished: { root.crtScanEnabled = text.trim() === "True"; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "vignette", "enabled"]
        stdout: StdioCollector {
            onStreamFinished: { root.crtVigEnabled = text.trim() === "True"; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "scanlines", "size"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseFloat(text.trim()); if (!isNaN(v)) root.crtScanSize = v; }
        }
    }
    Process {
        running: true
        command: ["brightnessctl", "-d", "kbd_backlight", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v)) root.kbdBacklightOn = v > 0;
            }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "bloom", "strength"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.crtBloomStrength = v; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "bloom", "enabled"]
        stdout: StdioCollector {
            onStreamFinished: { root.crtBloomEnabled = text.trim() === "True"; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "chromatic", "offset"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.crtChromOffset = v; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "chromatic", "enabled"]
        stdout: StdioCollector {
            onStreamFinished: { root.crtChromEnabled = text.trim() === "True"; }
        }
    }
    Process {
        running: true
        command: ["crt-shader", "get", "curvature", "amount"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.crtCurvAmount = v; }
        }
    }

    // ── Active shader detection ──────────────────────────────────────────────
    Process {
        running: true
        command: ["hyprctl", "getoption", "decoration:screen_shader", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const path = JSON.parse(text).str || "";
                    if      (path.includes("lcd-front.glsl")) root.shaderMode = "frontlit";
                    else if (path.includes("lcd-back.glsl"))  root.shaderMode = "backlit";
                    else if (path.includes("crt.glsl"))       root.shaderMode = "crt";
                    else                                      root.shaderMode = "none";
                } catch(e) {}
            }
        }
    }

    // ── LCD shared init ──────────────────────────────────────────────────────
    Process {
        running: true
        command: ["lcd-shader", "get", "dots", "pitch"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseFloat(text.trim()); if (!isNaN(v)) root.lcdPitch = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "dots", "enabled"]
        stdout: StdioCollector {
            onStreamFinished: { root.lcdEnabled = text.trim() === "True"; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "dots", "gap"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseFloat(text.trim()); if (!isNaN(v)) root.lcdGap = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "dots", "round"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdRound = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "brightness", "amount"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdBright = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "vignette", "strength"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdVigStr = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "intensity", "amount"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdIntensity = v; }
        }
    }

    // ── LCD frontlit init ────────────────────────────────────────────────────
    Process {
        running: true
        command: ["lcd-shader", "get", "shadow", "gap_light"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdGapLight = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "shadow", "strength"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.lcdShadowStr = v; }
        }
    }
    Process {
        running: true
        command: ["lcd-shader", "get", "shadow", "distance"]
        stdout: StdioCollector {
            onStreamFinished: { const v = parseFloat(text.trim()); if (!isNaN(v)) root.lcdShadowDist = v; }
        }
    }

    // ── Main OSD section ─────────────────────────────────────────────────────
    Item {
        id: mainSection
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width: mainLayout.implicitWidth + root.padL * 2

        ColumnLayout {
            id: mainLayout
            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0) Audio.incrementVolume();
                    else if (event.angleDelta.y < 0) Audio.decrementVolume();
                }
                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight
                FilledSlider {
                    anchors.fill: parent
                    icon: Icons.getVolumeIcon(value, root.muted)
                    value: root.volume
                    to: GlobalConfig.services.maxVolume
                    onMoved: Audio.setVolume(value)
                }
            }

            WrappedLoader {
                shouldBeActive: Config.osd.enableMicrophone && (!Config.osd.enableBrightness || !root.visibilities.session)
                sourceComponent: CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        if (event.angleDelta.y > 0) Audio.incrementSourceVolume();
                        else if (event.angleDelta.y < 0) Audio.decrementSourceVolume();
                    }
                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight
                    FilledSlider {
                        anchors.fill: parent
                        icon: Icons.getMicVolumeIcon(value, root.sourceMuted)
                        value: root.sourceVolume
                        to: GlobalConfig.services.maxVolume
                        onMoved: Audio.setSourceVolume(value)
                    }
                }
            }

            WrappedLoader {
                shouldBeActive: Config.osd.enableBrightness
                sourceComponent: CustomMouseArea {
                    function onWheel(event: WheelEvent) {
                        const monitor = root.monitor;
                        if (!monitor) return;
                        if (event.angleDelta.y > 0)
                            monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                        else if (event.angleDelta.y < 0)
                            monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                    }
                    implicitWidth: Tokens.sizes.osd.sliderWidth
                    implicitHeight: Tokens.sizes.osd.sliderHeight
                    FilledSlider {
                        anchors.fill: parent
                        icon: `brightness_${(Math.round(value * 6) + 1)}`
                        value: root.brightness
                        onMoved: root.monitor?.setBrightness(value)
                    }
                }
            }

            Item {
                implicitWidth:  Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                Rectangle {
                    anchors.centerIn: parent
                    width:  parent.width - 8
                    height: 72
                    radius: (parent.width - 8) / 2
                    color: root.kbdBacklightOn
                        ? Qt.alpha(root.clrFg, 0.12) : Qt.alpha(root.clrFg, 0.05)
                    border.width: 1
                    border.color: root.kbdBacklightOn
                        ? Qt.alpha(root.clrOutline, 0.6) : Qt.alpha(root.clrOutlineVar, 0.3)
                    Behavior on color        { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "keyboard"
                            font.family: "Material Symbols Rounded"; font.pixelSize: 16
                            color: root.kbdBacklightOn
                                ? Qt.alpha(root.clrFg, 0.87) : Qt.alpha(root.clrFg, 0.38)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.kbdBacklightOn ? "on" : "off"
                            font.family: "JetBrains Mono NF"; font.pixelSize: 10
                            color: root.kbdBacklightOn
                                ? Qt.alpha(root.clrFg, 0.60) : Qt.alpha(root.clrFg, 0.28)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            root.kbdBacklightOn = !root.kbdBacklightOn;
                            Quickshell.execDetached(["brightnessctl", "-d", "kbd_backlight", "s",
                                                     root.kbdBacklightOn ? "100%" : "0%"]);
                        }
                    }
                }
            }
        }
    }

    // ── Arrow button ─────────────────────────────────────────────────────────
    Item {
        id: arrowZone
        width: root.arrowW
        anchors.left:   mainSection.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            anchors.centerIn: parent
            width: 20; height: 48; radius: 6
            color: arrowHover.containsMouse ? Qt.alpha(root.clrFg, 0.08) : "transparent"
            Text {
                anchors.centerIn: parent
                text: root.submenuOpen ? "chevron_left" : "chevron_right"
                font.family: "Material Symbols Rounded"; font.pixelSize: 16
                color: Qt.alpha(root.clrFg, 0.60)
            }
            HoverHandler { id: arrowHover }
            TapHandler   { onTapped: root.submenuOpen = !root.submenuOpen }
        }
    }

    // ── Submenu panel ────────────────────────────────────────────────────────
    Item {
        id: subPanel
        readonly property real targetW: subLayout.implicitWidth + 24

        anchors.left:   arrowZone.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width: root.submenuOpen ? targetW : 0
        clip: true
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: subLayout
            anchors.left:           parent.left
            anchors.leftMargin:     8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // ── Mode selector ────────────────────────────────────────────────
            // 4 pills: none / CRT / back(lit) / front(lit)
            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { id: "none",     label: "none"  },
                        { id: "crt",      label: "CRT"   },
                        { id: "backlit",  label: "back"  },
                        { id: "frontlit", label: "front" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: root.shaderMode === modelData.id

                        implicitWidth: 52; implicitHeight: 22; radius: 11
                        color:        active ? Qt.alpha(root.clrFg, 0.12) : Qt.alpha(root.clrFg, 0.05)
                        border.width: 1
                        border.color: active ? Qt.alpha(root.clrOutline, 0.7) : Qt.alpha(root.clrOutlineVar, 0.4)
                        Behavior on color        { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "JetBrains Mono NF"; font.pixelSize: 10
                            color: active ? root.clrFg : Qt.alpha(root.clrFg, 0.5)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        TapHandler {
                            onTapped: {
                                const id = modelData.id;
                                root.shaderMode = id;
                                if (id === "none")
                                    Quickshell.execDetached(["shader-none"]);
                                else if (id === "crt")
                                    Quickshell.execDetached(["crt-shader", "apply"]);
                                else
                                    Quickshell.execDetached(["lcd-shader", "mode", id]);
                            }
                        }
                    }
                }
            }

            // ── Slider area ──────────────────────────────────────────────────
            // Layout (all modes capped at 4 rows tall):
            //   Blur col  (always, 2 rows): blur size, blur passes
            //   CRT col 1 (crt,    2 rows): scanlines, scanline size
            //   CRT col 2 (crt,    4 rows): vignette, bloom, rgb, curvature
            //   LCD col A (back|front, 4): dot size, gap, round, vignette
            //   LCD-back col B (back, 2): boost, intensity
            //   LCD-front col B (front, 4): boost, intensity, gap light, shadow
            //   LCD-front col C (front, 1): shadow dist
            RowLayout {
                spacing: Tokens.spacing.normal

                // ── Blur (always visible) ────────────────────────────────────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "blur size"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(1, Math.min(40, root.blurSize + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.blurSize = v;
                            Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:size", v.toString()]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "blur_on"
                            from: 0.01; to: 0.40; stepSize: 0.01
                            value: root.blurSize / 100.0
                            onMoved: {
                                root.blurSize = Math.round(value * 100);
                                Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:size", root.blurSize.toString()]);
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "blur passes"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(1, Math.min(10, root.blurPasses + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.blurPasses = v;
                            Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:passes", v.toString()]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "layers"
                            from: 0.01; to: 0.10; stepSize: 0.01
                            value: root.blurPasses / 100.0
                            onMoved: {
                                root.blurPasses = Math.round(value * 100);
                                Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:passes", root.blurPasses.toString()]);
                            }
                        }
                    }
                }

                } // end blur col

                // ── CRT col 1: scanlines (visible=crt) ──────────────────────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "crt"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "scanlines"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(50, root.crtScanIntensity + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.crtScanIntensity = v;
                            Quickshell.execDetached(["crt-shader", "save", "scanlines", "intensity", v.toString()]);
                            shaderApplyTimer.restart();
                        }
                        function onClicked(event: MouseEvent) {
                            root.crtScanEnabled = !root.crtScanEnabled;
                            Quickshell.execDetached(["crt-shader", "toggle", "scanlines"]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "tv"
                            from: 0.0; to: 0.50; stepSize: 0.01
                            value: root.crtScanEnabled ? root.crtScanIntensity / 100.0 : 0.0
                            onMoved: {
                                root.crtScanIntensity = Math.round(value * 100);
                                Quickshell.execDetached(["crt-shader", "save", "scanlines", "intensity", root.crtScanIntensity.toString()]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "scanline size"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.round(Math.max(1.0, Math.min(8.0,
                                root.crtScanSize + (event.angleDelta.y > 0 ? 0.25 : -0.25))) * 4) / 4;
                            root.crtScanSize = v;
                            Quickshell.execDetached(["crt-shader", "save", "scanlines", "size", v.toFixed(2)]);
                            shaderApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "dehaze"
                            from: 0.0; to: 7.0; stepSize: 0.25
                            value: root.crtScanSize - 1.0
                            onMoved: {
                                const actual = value + 1.0;
                                root.crtScanSize = actual;
                                Quickshell.execDetached(["crt-shader", "save", "scanlines", "size", actual.toFixed(2)]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end CRT col 1

                // ── CRT col 2: vignette/bloom/rgb/curv (visible=crt) ─────────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "crt"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "vignette"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(300, root.crtVigStrength + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.crtVigStrength = v;
                            Quickshell.execDetached(["crt-shader", "save", "vignette", "strength", v.toString()]);
                            shaderApplyTimer.restart();
                        }
                        function onClicked(event: MouseEvent) {
                            root.crtVigEnabled = !root.crtVigEnabled;
                            Quickshell.execDetached(["crt-shader", "toggle", "vignette"]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "filter_tilt_shift"
                            from: 0.0; to: 3.0; stepSize: 0.05
                            value: root.crtVigEnabled ? root.crtVigStrength / 100.0 : 0.0
                            onMoved: {
                                root.crtVigStrength = Math.round(value * 100);
                                Quickshell.execDetached(["crt-shader", "save", "vignette", "strength", root.crtVigStrength.toString()]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "bloom"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(50, root.crtBloomStrength + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.crtBloomStrength = v;
                            Quickshell.execDetached(["crt-shader", "save", "bloom", "strength", v.toString()]);
                            shaderApplyTimer.restart();
                        }
                        function onClicked(event: MouseEvent) {
                            root.crtBloomEnabled = !root.crtBloomEnabled;
                            Quickshell.execDetached(["crt-shader", "toggle", "bloom"]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "flare"
                            from: 0.0; to: 0.50; stepSize: 0.01
                            value: root.crtBloomEnabled ? root.crtBloomStrength / 100.0 : 0.0
                            onMoved: {
                                root.crtBloomStrength = Math.round(value * 100);
                                Quickshell.execDetached(["crt-shader", "save", "bloom", "strength", root.crtBloomStrength.toString()]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "rgb"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(10, root.crtChromOffset + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.crtChromOffset = v;
                            Quickshell.execDetached(["crt-shader", "save", "chromatic", "offset", v.toString()]);
                            shaderApplyTimer.restart();
                        }
                        function onClicked(event: MouseEvent) {
                            root.crtChromEnabled = !root.crtChromEnabled;
                            Quickshell.execDetached(["crt-shader", "toggle", "chromatic"]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "colorize"
                            from: 0.0; to: 0.10; stepSize: 0.01
                            value: root.crtChromEnabled ? root.crtChromOffset / 100.0 : 0.0
                            onMoved: {
                                root.crtChromOffset = Math.round(value * 100);
                                Quickshell.execDetached(["crt-shader", "save", "chromatic", "offset", root.crtChromOffset.toString()]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "curvature"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(30, root.crtCurvAmount + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.crtCurvAmount = v;
                            Quickshell.execDetached(["crt-shader", "save", "curvature", "amount", v.toString()]);
                            shaderApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "rounded_corner"
                            from: 0.0; to: 0.30; stepSize: 0.01
                            value: root.crtCurvAmount / 100.0
                            onMoved: {
                                root.crtCurvAmount = Math.round(value * 100);
                                Quickshell.execDetached(["crt-shader", "save", "curvature", "amount", root.crtCurvAmount.toString()]);
                                shaderApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end CRT col 2

                // ── LCD col A: shared dot controls (back | front) ────────────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "backlit" || root.shaderMode === "frontlit"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "dot size"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(2, Math.min(20,
                                Math.round(root.lcdPitch) + (event.angleDelta.y > 0 ? 1 : -1)));
                            root.lcdPitch = v;
                            Quickshell.execDetached(["lcd-shader", "save", "dots", "pitch", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        function onClicked(event: MouseEvent) {
                            root.lcdEnabled = !root.lcdEnabled;
                            Quickshell.execDetached(["lcd-shader", "toggle", "dots"]);
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "grid_view"
                            from: 2.0; to: 20.0; stepSize: 1.0
                            value: root.lcdEnabled ? root.lcdPitch : 2.0
                            onMoved: {
                                root.lcdPitch = Math.round(value);
                                Quickshell.execDetached(["lcd-shader", "save", "dots", "pitch",
                                                         Math.round(value).toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "gap"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.round(Math.max(0, Math.min(25,
                                root.lcdGap + (event.angleDelta.y > 0 ? 0.25 : -0.25))) * 4) / 4;
                            root.lcdGap = v;
                            Quickshell.execDetached(["lcd-shader", "save", "dots", "gap", v.toFixed(2)]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "border_clear"
                            from: 0.0; to: 25.0; stepSize: 0.25
                            value: root.lcdGap
                            onMoved: {
                                root.lcdGap = Math.round(value * 4) / 4;
                                Quickshell.execDetached(["lcd-shader", "save", "dots", "gap",
                                                         root.lcdGap.toFixed(2)]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "round"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(70,
                                root.lcdRound + (event.angleDelta.y > 0 ? 2 : -2)));
                            root.lcdRound = v;
                            Quickshell.execDetached(["lcd-shader", "save", "dots", "round", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "radio_button_unchecked"
                            from: 0; to: 70; stepSize: 2
                            value: root.lcdRound
                            onMoved: {
                                root.lcdRound = Math.round(value / 2) * 2;
                                Quickshell.execDetached(["lcd-shader", "save", "dots", "round",
                                                         root.lcdRound.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "vignette"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(200, root.lcdVigStr + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdVigStr = v;
                            Quickshell.execDetached(["lcd-shader", "save", "vignette", "strength", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "filter_tilt_shift"
                            from: 0.0; to: 2.0; stepSize: 0.05
                            value: root.lcdVigStr / 100.0
                            onMoved: {
                                root.lcdVigStr = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "vignette", "strength",
                                                         root.lcdVigStr.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end LCD col A

                // ── LCD-back col B: boost + intensity (visible=backlit) ───────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "backlit"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "boost"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(50, Math.min(200, root.lcdBright + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdBright = v;
                            Quickshell.execDetached(["lcd-shader", "save", "brightness", "amount", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "light_mode"
                            from: 0.50; to: 2.0; stepSize: 0.05
                            value: root.lcdBright / 100.0
                            onMoved: {
                                root.lcdBright = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "brightness", "amount",
                                                         root.lcdBright.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "intensity"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(100, root.lcdIntensity + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdIntensity = v;
                            Quickshell.execDetached(["lcd-shader", "save", "intensity", "amount", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "opacity"
                            from: 0.0; to: 1.0; stepSize: 0.05
                            value: root.lcdIntensity / 100.0
                            onMoved: {
                                root.lcdIntensity = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "intensity", "amount",
                                                         root.lcdIntensity.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end LCD-back col B

                // ── LCD-front col B: boost / intensity / gap light / shadow ──
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "frontlit"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "boost"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(50, Math.min(200, root.lcdBright + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdBright = v;
                            Quickshell.execDetached(["lcd-shader", "save", "brightness", "amount", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "light_mode"
                            from: 0.50; to: 2.0; stepSize: 0.05
                            value: root.lcdBright / 100.0
                            onMoved: {
                                root.lcdBright = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "brightness", "amount",
                                                         root.lcdBright.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                SubSliderRow {
                    label: "intensity"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(100, root.lcdIntensity + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdIntensity = v;
                            Quickshell.execDetached(["lcd-shader", "save", "intensity", "amount", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "opacity"
                            from: 0.0; to: 1.0; stepSize: 0.05
                            value: root.lcdIntensity / 100.0
                            onMoved: {
                                root.lcdIntensity = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "intensity", "amount",
                                                         root.lcdIntensity.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                // Gap light: how bright the reflector gap is (0=none, 50%=bright).
                // Must be > 0 for shadow to be visible.
                SubSliderRow {
                    label: "gap light"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(50, root.lcdGapLight + (event.angleDelta.y > 0 ? 2 : -2)));
                            root.lcdGapLight = v;
                            Quickshell.execDetached(["lcd-shader", "save", "shadow", "gap_light", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "wb_sunny"
                            from: 0.0; to: 0.50; stepSize: 0.02
                            value: root.lcdGapLight / 100.0
                            onMoved: {
                                root.lcdGapLight = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "shadow", "gap_light",
                                                         root.lcdGapLight.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                // Shadow: pixel cells cast parallax shadow into the lit gap.
                // Visible only when gap light > 0.
                SubSliderRow {
                    label: "shadow"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.max(0, Math.min(100, root.lcdShadowStr + (event.angleDelta.y > 0 ? 5 : -5)));
                            root.lcdShadowStr = v;
                            Quickshell.execDetached(["lcd-shader", "save", "shadow", "strength", v.toString()]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "shadow"
                            from: 0.0; to: 1.0; stepSize: 0.05
                            value: root.lcdShadowStr / 100.0
                            onMoved: {
                                root.lcdShadowStr = Math.round(value * 100);
                                Quickshell.execDetached(["lcd-shader", "save", "shadow", "strength",
                                                         root.lcdShadowStr.toString()]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end LCD-front col B

                // ── LCD-front col C: shadow distance (visible=frontlit) ───────
                ColumnLayout {
                    spacing: Tokens.spacing.normal
                    visible: root.shaderMode === "frontlit"
                    Layout.alignment: Qt.AlignTop

                SubSliderRow {
                    label: "shd dist"
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const v = Math.round(Math.max(1.0, Math.min(8.0,
                                root.lcdShadowDist + (event.angleDelta.y > 0 ? 0.5 : -0.5))) * 2) / 2;
                            root.lcdShadowDist = v;
                            Quickshell.execDetached(["lcd-shader", "save", "shadow", "distance", v.toFixed(1)]);
                            lcdApplyTimer.restart();
                        }
                        implicitWidth: Tokens.sizes.osd.sliderWidth; implicitHeight: Tokens.sizes.osd.sliderHeight
                        FilledSlider {
                            anchors.fill: parent; icon: "unfold_more"
                            from: 1.0; to: 8.0; stepSize: 0.5
                            value: root.lcdShadowDist
                            onMoved: {
                                root.lcdShadowDist = Math.round(value * 2) / 2;
                                Quickshell.execDetached(["lcd-shader", "save", "shadow", "distance",
                                                         root.lcdShadowDist.toFixed(1)]);
                                lcdApplyTimer.restart();
                            }
                        }
                    }
                }

                } // end LCD-front col C

            } // end slider RowLayout
        } // end subLayout
    } // end subPanel

    // ── Reusable: labelled submenu slider row ─────────────────────────────────
    component SubSliderRow: ColumnLayout {
        required property string label
        default property alias content: slotItem.data
        spacing: 2

        Text {
            text: parent.label
            font.family: "JetBrains Mono NF"; font.pixelSize: 10
            color: Qt.alpha(root.clrFgVariant, 0.9)
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            id: slotItem
            Layout.preferredWidth:  Tokens.sizes.osd.sliderWidth
            Layout.preferredHeight: Tokens.sizes.osd.sliderHeight
        }
    }

    // ── Reusable: animated show/hide loader ───────────────────────────────────
    component WrappedLoader: Loader {
        required property bool shouldBeActive
        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active
        Behavior on Layout.preferredHeight { Anim { type: Anim.Emphasized } }
        Behavior on opacity                { Anim {} }
    }
}
