pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    readonly property date today: new Date()
    property int displayYear: today.getFullYear()
    property int displayMonth: today.getMonth()  // 0–11

    // Monday-first week: Sun(0)→6, Mon(1)→0, Tue(2)→1, ... Sat(6)→5
    readonly property int startOffset: (new Date(displayYear, displayMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(displayYear, displayMonth + 1, 0).getDate()

    readonly property int cellSize: 26
    readonly property int cellGap: 4

    implicitWidth: cellSize * 7 + cellGap * 6 + Tokens.padding.large * 2
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2

    Column {
        id: col

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        // ── Month navigation header ─────────────────────────────────────
        Item {
            width: root.implicitWidth - Tokens.padding.large * 2
            height: monthLabel.implicitHeight + Tokens.padding.smaller * 2

            MouseArea {
                width: root.cellSize * 1.5
                height: parent.height
                anchors.left: parent.left
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.displayMonth === 0) {
                        root.displayYear -= 1;
                        root.displayMonth = 11;
                    } else {
                        root.displayMonth -= 1;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.normal
                }
            }

            StyledText {
                id: monthLabel

                anchors.centerIn: parent
                text: Qt.locale().monthName(root.displayMonth, Locale.LongFormat) + " " + root.displayYear
                font.weight: 500
                font.pointSize: Tokens.font.size.smaller
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                width: root.cellSize * 1.5
                height: parent.height
                anchors.right: parent.right
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.displayMonth === 11) {
                        root.displayYear += 1;
                        root.displayMonth = 0;
                    } else {
                        root.displayMonth += 1;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.normal
                }
            }
        }

        // ── Day-of-week header row (Mon … Sun) ──────────────────────────
        Row {
            spacing: root.cellGap

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                StyledText {
                    required property string modelData
                    required property int index

                    width: root.cellSize
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pointSize: Tokens.font.size.smaller - 1
                    opacity: 0.55
                    color: index >= 5 ? Colours.palette.m3error : Colours.palette.m3onSurface
                }
            }
        }

        // ── Day grid (6 weeks × 7 days = 42 cells) ──────────────────────
        Grid {
            columns: 7
            rowSpacing: root.cellGap
            columnSpacing: root.cellGap

            Repeater {
                model: 42

                Item {
                    required property int index

                    readonly property int dayNum: index - root.startOffset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= root.daysInMonth
                    readonly property bool isToday: inMonth
                        && dayNum === root.today.getDate()
                        && root.displayMonth === root.today.getMonth()
                        && root.displayYear === root.today.getFullYear()
                    readonly property bool isWeekend: (index % 7) >= 5

                    width: root.cellSize
                    height: root.cellSize

                    // Today highlight circle
                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: isToday ? Colours.palette.m3primary : "transparent"
                        visible: inMonth
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: inMonth
                        text: dayNum
                        font.pointSize: Tokens.font.size.smaller - 1
                        font.weight: isToday ? 700 : 400
                        color: isToday
                            ? Colours.palette.m3onPrimary
                            : isWeekend
                                ? Colours.palette.m3error
                                : Colours.palette.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
