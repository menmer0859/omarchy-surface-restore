import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons as Commons

Item {
    id: root
    property string userName: ""
    property string displayName: ""
    property string avatarPath: ""
    readonly property string label: displayName || userName
    readonly property bool vertical: portrait.status === Image.Ready
    implicitWidth: vertical ? Math.max(120, nameLabel.implicitWidth) : logo.width + horizontalName.implicitWidth + 12
    implicitHeight: vertical ? 146 : 44
    Accessible.role: Accessible.StaticText
    Accessible.name: strings.t("identity.label", "Account: %1").arg(label)
    AuthStrings {
        id: strings
    }
    Image {
        id: portrait
        source: root.avatarPath.startsWith("/") && !root.avatarPath.startsWith("//") ? "file://" + root.avatarPath.split("/").map(encodeURIComponent).join("/") : ""
        width: 100
        height: 100
        anchors.horizontalCenter: parent.horizontalCenter
        visible: false
        asynchronous: true
        sourceSize.width: 200
        sourceSize.height: 200
        fillMode: Image.PreserveAspectCrop
        // A round frame avoids modifying the user's actual image.
    }
    Canvas {
        id: avatarCanvas
        anchors.fill: portrait
        visible: root.vertical
        property url imageUrl: portrait.source
        onImageUrlChanged: {
            if (imageUrl)
                loadImage(imageUrl);
            requestPaint();
        }
        onImageLoaded: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (!isImageLoaded(imageUrl))
                return;
            c.beginPath();
            c.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2);
            c.clip();
            var ratio = Math.max(width / Math.max(1, portrait.implicitWidth), height / Math.max(1, portrait.implicitHeight));
            var w = portrait.implicitWidth * ratio;
            var h = portrait.implicitHeight * ratio;
            c.drawImage(imageUrl, (width - w) / 2, (height - h) / 2, w, h);
        }
    }
    Rectangle {
        anchors.fill: portrait
        visible: root.vertical
        color: "transparent"
        radius: 50
        border.width: 2
        border.color: Qt.alpha(Commons.Color.foreground, 0.2)
    }
    Image {
        id: logo
        visible: !root.vertical
        width: 40
        height: 40
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        source: "/usr/share/omarchy/icon.png"
        fillMode: Image.PreserveAspectFit
    }
    Label {
        id: horizontalName
        visible: !root.vertical
        text: root.label
        font.pixelSize: 19
        anchors.left: logo.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(implicitWidth, root.width - 52))
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
    Label {
        id: nameLabel
        objectName: "identityName"
        visible: root.vertical
        text: root.label
        font.pixelSize: 19
        anchors.top: portrait.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
}
