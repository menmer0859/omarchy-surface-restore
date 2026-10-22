import QtQuick

Canvas {
    id: root
    property string name: "face"
    property color ink: "white"
    implicitWidth: 24
    implicitHeight: 24
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink;
        c.fillStyle = ink;
        c.lineWidth = 1.7;
        c.lineCap = "round";
        c.lineJoin = "round";
        function line(x1, y1, x2, y2) {
            c.beginPath();
            c.moveTo(x1, y1);
            c.lineTo(x2, y2);
            c.stroke();
        }
        function dot(x, y, r) {
            c.beginPath();
            c.arc(x, y, r, 0, Math.PI * 2);
            c.fill();
        }
        if (name === "password") {
            for (var x = 6; x <= 18; x += 6)
                for (var y = 6; y <= 18; y += 6)
                    dot(x, y, 1.35);
        } else if (name === "face") {
            line(3, 8, 3, 3);
            line(3, 3, 8, 3);
            line(16, 3, 21, 3);
            line(21, 3, 21, 8);
            line(3, 16, 3, 21);
            line(3, 21, 8, 21);
            line(16, 21, 21, 21);
            line(21, 21, 21, 16);
            dot(8, 9, 0.8);
            dot(16, 9, 0.8);
            c.beginPath();
            c.arc(12, 12, 5, 0.4, Math.PI - 0.4);
            c.stroke();
        } else if (name === "check") {
            line(5, 12, 10, 17);
            line(10, 17, 20, 6);
        } else if (name === "clock") {
            c.beginPath();
            c.arc(12, 12, 9, 0, Math.PI * 2);
            c.stroke();
            line(12, 7, 12, 12);
            line(12, 12, 16, 14);
        } else if (name === "screen") {
            c.strokeRect(3, 4, 18, 13);
            line(12, 17, 12, 21);
            line(7, 21, 17, 21);
        } else if (name === "lock") {
            c.strokeRect(6, 10, 12, 11);
            c.beginPath();
            c.arc(12, 10, 4, Math.PI, 0);
            c.stroke();
            dot(12, 15, 1);
        } else if (name === "eye" || name === "eyeOff") {
            c.beginPath();
            c.moveTo(2, 12);
            c.quadraticCurveTo(12, 0, 22, 12);
            c.quadraticCurveTo(12, 24, 2, 12);
            c.stroke();
            c.beginPath();
            c.arc(12, 12, 3, 0, Math.PI * 2);
            c.stroke();
            if (name === "eyeOff")
                line(3, 3, 21, 21);
        } else if (name === "arrow") {
            line(4, 12, 20, 12);
            line(14, 6, 20, 12);
            line(14, 18, 20, 12);
        } else {
            line(6, 6, 18, 18);
            line(18, 6, 6, 18);
        }
    }
}
