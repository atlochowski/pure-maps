/* -*- coding: utf-8-unix -*-
 *
 * Copyright (C) 2014 Osmo Salomaa, 2018 Rinigus
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import "."
import "platform"

PagePL {
    id: page
    title: app.tr("Navigation")

    acceptIconName: styler.iconNavigate
    acceptText: app.tr("Route")
    canNavigateForward: {
        if (page.fromNeeded && (!page.from || (page.fromText === app.tr("Current position") && !gps.ready)) )
            return false;
        if (page.toNeeded && (!page.to || (page.toText === app.tr("Current position") && !gps.ready)) )
            return false;
        if (waypointsEnabled)
            for (var i=0; i < waypoints.count; ++i)
                if (!waypoints.get(i).set || (waypoints.get(i).text === app.tr("Current position") && !gps.ready))
                    return false;
        return true;
    }

    pageMenu: PageMenuPL {
        PageMenuItemPL {
            iconName: styler.iconPreferences
            text: app.tr("Change provider (%1)").arg(name)
            property string name: page.routerName
            onClicked: {
                var dialog = app.push(Qt.resolvedUrl("RouterPage.qml"));
                dialog.accepted.connect(function() {
                    page.updateRouter();
                    columnRouter.settings && columnRouter.settings.destroy();
                    columnRouter.settings = null;
                    columnRouter.addSettings();
                });
            }
        }

        PageMenuItemPL {
            iconName: styler.iconNavigate
            text: followMe ? app.tr("Navigate") : app.tr("Follow me")
            onClicked: {
                followMe = !followMe;
                page.params = {};
                columnRouter.settings && columnRouter.settings.destroy();
                columnRouter.settings = null;
                columnRouter.addSettings();
            }
        }

        PageMenuItemPL {
            iconName: styler.iconNavigateTo
            text: app.tr("Reverse route")
            visible: page.fromNeeded && page.toNeeded
            onClicked: {
                var from = page.from;
                var fromQuery = page.fromQuery;
                var fromText = page.fromText;
                page.from = page.to;
                page.fromQuery = page.toQuery;
                page.fromText = page.toText;
                page.to = from;
                page.toQuery = fromQuery;
                page.toText = fromText;
                for (var i = waypoints.count - 2; i >= 0; i--)
                    waypoints.move(i, waypoints.count - 1, 1);
            }
        }
    }

    property bool   autoRoute: false
    property bool   autoRouteSupported: false
    property var    columnRouter
    property bool   followMe: false
    property alias  from: fromButton.coordinates
    property bool   fromNeeded: true
    property alias  fromQuery: fromButton.query
    property alias  fromText: fromButton.text
    property alias  optimized: optimizeSwitch.checked
    property var    params: {}
    property string routerName
    property alias  to: toButton.coordinates
    property bool   toNeeded: true
    property alias  toQuery: toButton.query
    property alias  toText: toButton.text
    property alias  waypointsEnabled: viaSwitch.checked
    property var    waypoints: ListModel {}

    property int    _autoRouteFlag: 0
    property var    _destinationsNotForSave: []

    signal notify(string notification)

    Column {
        id: column
        spacing: styler.themePaddingLarge
        width: parent.width

        Column {
            id: columnRouter
            spacing: styler.themePaddingMedium
            visible: !followMe
            width: parent.width

            property var  settings: null

            ListItemLabel {
                id: note
                color: styler.themeHighlightColor
                horizontalAlignment: Text.AlignHCenter
                visible: text

                Timer {
                    id: nt
                    interval: 3000; repeat: false; running: false;
                    onTriggered: note.text = ""
                }

                Connections {
                    target: page
                    onNotify: {
                        note.text = notification;
                        nt.start();
                    }
                }
            }

            RoutePoint {
                id: fromButton
                label: app.tr("From")
                title: app.tr("Origin")
                visible: page.fromNeeded
            }

            RoutePoint {
                id: toButton
                label: app.tr("To")
                title: app.tr("Destination")
                visible: page.toNeeded
            }

            TextSwitchPL {
                id: viaSwitch
                checked: false
                text: app.tr("Destinations and waypoints")
                visible: page.toNeeded

                onCheckedChanged: {
                    if (checked && !app.conf.routePageShowDestinationsHelpShown && app.conf.routePageShowDestinationsHelp) {
                        var d = app.push(Qt.resolvedUrl("MessagePage.qml"), {
                                             "acceptText": app.tr("Dismiss"),
                                             "title": app.tr("Destinations and waypoints"),
                                             "message": app.tr("Additional destinations and wayponts can be added along the route. " +
                                                               "The both locations are used for calculation of the route, but only " +
                                                               "destinations are tracked for being reached. As a result, if you miss the " +
                                                               "waypoint and later rejoin the calculated route after the waypoint, " +
                                                               "it will be assumed that waypoint was reached and it will be dismissed in the rerouting calculations " +
                                                               "later. In contrast, destinations have to be reached within the " +
                                                               "certain tolerance and will not be dismissed in such manner.\n\n" +
                                                               "So, set as destination the locations that you need to reach on your route and as " +
                                                               "waypoints the locations that are just for shaping the route according to your preferences.\n\n" +
                                                               "Dismiss this dialog to stop showing this message.")
                                         });
                        app.conf.routePageShowDestinationsHelpShown = true;
                        d.accepted.connect(function () {
                            app.conf.routePageShowDestinationsHelp = false;
                        });
                    }
                }
            }

            TextSwitchPL {
                id: optimizeSwitch
                checked: false
                text: app.tr("Optimize order")
                visible: page.toNeeded && waypoints.count > 1
            }

            Column {
                id: waypointsColumn
                visible: waypointsEnabled
                width: parent.width

                Spacer {
                    height: styler.themePaddingMedium
                }

                Repeater {
                    model: waypoints
                    delegate: ListItemPL {
                        id: waypointsItem
                        contentHeight: styler.themeItemSizeSmall
                        menu: ContextMenuPL {
                            ContextMenuItemPL {
                                visible: model.index > 0
                                iconName: styler.iconUp
                                text: app.tr("Up")
                                onClicked: {
                                    if (model.index > 0)
                                        waypoints.move(model.index, model.index-1, 1);
                                }
                            }
                            ContextMenuItemPL {
                                visible: model.index < waypoints.count - 1
                                iconName: styler.iconDown
                                text: app.tr("Down")
                                onClicked: {
                                    if (model.index < waypoints.count - 1)
                                        waypoints.move(model.index, model.index+1, 1);
                                }
                            }
                            ContextMenuItemPL {
                                iconName: styler.iconDelete
                                text: app.tr("Remove")
                                onClicked: waypoints.remove(model.index)
                            }
                            ContextMenuItemPL {
                                iconName: styler.iconEdit
                                text: model.destination ?
                                          app.tr("Convert to waypoint") :
                                          app.tr("Convert to destination")
                                onClicked: model.destination = (model.destination ? 0 : 1)
                            }
                        }

                        ListItemLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: waypointsItem.highlighted ?
                                       styler.themeHighlightColor :
                                       styler.themePrimaryColor
                            text: model.destination ?
                                      app.tr("Destination: %1", model.text) :
                                      app.tr("Waypoint: %1", model.text)
                        }

                        onClicked: waypointsColumn.edit(model.index)
                    }
                }

                Spacer {
                    height: styler.themePaddingLarge
                    visible: waypoints.count > 0
                }

                Item {
                    id: bLayout
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: onerow ?
                                Math.max(wpb1.height, wpb2.height) :
                                wpb1.height + wpb2.height + styler.themePaddingLarge
                    width: onerow ?
                               wpb1.width + wpb2.width + styler.themePaddingLarge :
                               Math.max(wpb1.width, wpb2.width)

                    property bool onerow: {
                        var tgt = waypointsColumn.width - 2*styler.themeHorizontalPageMargin -
                                styler.themePaddingMedium;
                        if (tgt < wpb1.width + wpb2.width)
                            return false;
                        return true;
                    }
                    property int spacing: styler.themePaddingLarge

                    ButtonPL {
                        id: wpb1
                        preferredWidth: styler.themeButtonWidthMedium
                        text: app.tr("Add destination")
                        x: bLayout.onerow ? 0 : bLayout.width/2 - width/2
                        onClicked: waypointsColumn.add(1)
                    }

                    ButtonPL {
                        id: wpb2
                        preferredWidth: styler.themeButtonWidthMedium
                        text: app.tr("Add waypoint")
                        x: bLayout.onerow ? bLayout.width - width : bLayout.width/2 - width/2
                        y: bLayout.onerow ? 0 : bLayout.height - height
                        onClicked: waypointsColumn.add(0)
                    }
                }

                Spacer {
                    height: styler.themePaddingLarge
                    visible: waypoints.count > 0
                }

                RoutePoint {
                    // this is invisible and shared by all waypoints
                    id: rpointWaypoint
                    anchors.verticalCenter: parent.verticalCenter
                    title: p && p.destination ? app.tr("Destination") : app.tr("Waypoint")
                    query: p ? p.query : ""
                    visible: false

                    property int index: -1
                    property var p: null

                    onIndexChanged: {
                        // have to specify manually as it uncouples property values when editing
                        if (index < 0 || index >= waypoints.count) {
                            p = null;
                            coordinates = null;
                            text = "";
                            query = "";
                        } else {
                            p = waypoints.get(index);
                            coordinates = [p.x, p.y];
                            text = p.text;
                            query = p.query;
                        }
                    }

                    onUpdated: {
                        waypoints.set(index, {
                                          "destination": p.destination,
                                          "set": true,
                                          "query": query,
                                          "text": text,
                                          "x": coordinates[0],
                                          "y": coordinates[1]
                                      });
                        index = -1;
                    }
                }

                function add(destination) {
                    waypoints.append({"destination": destination,
                                         "set": false,
                                         "query": "",
                                         "text": "",
                                         "x": 0.0,
                                         "y": 0.0});
                    edit(waypoints.count - 1);
                }

                function edit(i) {
                    rpointWaypoint.index = i;
                    rpointWaypoint.activate();
                }
            }

            Component.onCompleted: {
                columnRouter.addSettings();
                page.columnRouter = columnRouter;
            }

            function addSettings() {
                if (columnRouter.settings || followMe) return;
                // Add router-specific settings from router's own QML file.
                page.params = {};
                columnRouter.settings && columnRouter.settings.destroy();
                var uri = Qt.resolvedUrl(py.evaluate("poor.app.router.settings_qml_uri"));
                if (!uri) return;
                var component = Qt.createComponent(uri);
                if (component.status === Component.Error) {
                    console.log('Error while creating component');
                    console.log(component.errorString());
                    return null;
                }
                columnRouter.settings = component.createObject(columnRouter);
                if (!columnRouter.settings) return;
                columnRouter.settings.anchors.left = columnRouter.left;
                columnRouter.settings.anchors.right = columnRouter.right;
                columnRouter.settings.width = columnRouter.width;
                columnRouter.settings.full = Qt.binding(function() {
                    return !followMe && (page.from!=null || !page.fromNeeded) &&
                            (page.to!=null || !page.toNeeded);
                });
            }
        }

        Column {
            /////////////////////////
            // Recent routes
            id: columnRoutes
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !followMe && !page.to && page.toNeeded && routes.model.count > 0

            property int numberOfRoutes: 2

            SectionHeaderPL {
                text: app.tr("Routes")
            }

            Spacer {
                height: styler.themePaddingMedium
            }

            Repeater {
                id: routes

                delegate: ListItemPL {
                    id: routesListItem
                    contentHeight: styler.themeItemSizeSmall
                    menu: ContextMenuPL {
                        ContextMenuItemPL {
                            iconName: styler.iconDelete
                            text: app.tr("Remove")
                            onClicked: {
                                py.call_sync("poor.app.history.remove_route", [JSON.parse(model.full)]);
                                columnRoutes.fillRoutes();
                            }
                        }
                    }

                    ListItemLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: routesListItem.highlighted ? styler.themeHighlightColor : styler.themePrimaryColor
                        text: model.waypoints ?
                                  app.tr("%1 ‒ %2 (%3 destinations and waypoints)", model.fromText, model.toText, model.waypoints) :
                                  "%1 ‒ %2".arg(model.fromText).arg(model.toText)
                    }

                    onClicked: {
                        page.fromText = model.fromText;
                        if (page.fromText === app.tr("Current position"))
                            page.from = app.getPosition();
                        else page.from = [model.fromX, model.fromY];

                        page.toText = model.toText;
                        if (page.toText === app.tr("Current position"))
                            page.to = app.getPosition();
                        else page.to = [model.toX, model.toY];

                        if (model.waypoints) {
                            var rfull= JSON.parse(model.full);
                            var r = rfull.locations;
                            page.waypoints.clear();
                            for (var i=1; i < r.length-1; i++)
                                page.waypoints.append({"destination": r[i].destination,
                                                          "set": true,
                                                          "query": "",
                                                          "text": r[i].text,
                                                          "x": r[i].x,
                                                          "y": r[i].y})
                            page.waypointsEnabled = true;
                            page.optimized = rfull.optimized;
                        } else {
                            page.waypointsEnabled = false;
                            page.optimized = false;
                            page.waypoints.clear();
                        }
                    }
                }

                model: ListModel {}
            }

            ListItemPL {
                contentHeight: styler.themeItemSizeSmall
                visible: columnRoutes.numberOfRoutes < 20 && routes.model.count === columnRoutes.numberOfRoutes
                ListItemLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: parent.highlighted ? styler.themeHighlightColor : styler.themePrimaryColor
                    text: app.tr("Show more...")
                }
                onClicked: {
                    columnRoutes.numberOfRoutes += 10;
                    columnRoutes.fillRoutes();
                }
            }

            Component.onCompleted: columnRoutes.fillRoutes()

            function fillRoutes() {
                // recent destinations
                routes.model.clear();
                var rs = py.evaluate("poor.app.history.routes").slice(0, numberOfRoutes);
                rs.forEach(function (r) {
                    var p = r.locations;
                    routes.model.append({
                                            "fromText": p[0].text,
                                            "fromX": p[0].x,
                                            "fromY": p[0].y,
                                            "toText": p[p.length-1].text,
                                            "toX": p[p.length-1].x,
                                            "toY": p[p.length-1].y,
                                            "visible": true,
                                            "full": JSON.stringify(r),
                                            "waypoints": p.length - 2
                                        });
                });
            }
        }

        Column {
            /////////////////////////
            // Suggested destinations
            id: columnSuggested
            anchors.left: parent.left
            anchors.right: parent.right
            visible: !followMe && !page.to && page.toNeeded

            SectionHeaderPL {
                text: app.tr("Destinations")
            }

            Spacer {
                height: styler.themePaddingMedium
            }

            Repeater {
                id: destinations

                delegate: ListItemPL {
                    id: destListItem
                    contentHeight: model.visible ? styler.themeItemSizeSmall : 0
                    menu: ContextMenuPL {
                        enabled: model.type === "recent destination"
                        ContextMenuItemPL {
                            enabled: model.type === "recent destination"
                            iconName: enabled ? styler.iconDelete : ""
                            text: enabled ? app.tr("Remove") : ""
                            onClicked: {
                                if (model.type !== "recent destination") return;
                                py.call_sync("poor.app.history.remove_destination", [model.text]);
                                model.visible = false;
                            }
                        }
                    }
                    visible: model.visible

                    ListItemLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: destListItem.highlighted ? styler.themeHighlightColor : styler.themePrimaryColor
                        text: model.text
                    }

                    onClicked: {
                        page.to = [model.x, model.y];
                        page.toText = model.toText;
                    }
                }

                model: ListModel {}
            }

            Component.onCompleted: {
                // pois
                _destinationsNotForSave = [];
                var pois = app.pois.pois.filter(function (p) {
                    return (p.bookmarked && p.shortlisted);
                });
                pois.sort(function (a, b){
                    if (a.title < b.title) return -1;
                    if (a.title > b.title) return 1;
                    return 0;
                })
                pois.forEach(function (p) {
                    var t = {
                        "text": (p.title ? p.title : app.tr("Unnamed point")) +
                                (p.shortlisted ? " ☰" : ""),
                        "toText": p.title ? p.title : app.tr("Unnamed point"),
                        "type": "poi",
                        "visible": true,
                        "x": p.coordinate.longitude,
                        "y": p.coordinate.latitude
                    };
                    destinations.model.append(t);
                    _destinationsNotForSave.push(t);
                });

                // recent destinations
                var dest = py.evaluate("poor.app.history.destinations").slice(0, 10);
                dest.forEach(function (p) {
                    destinations.model.append({
                                                  "text": p.text,
                                                  "toText": p.text,
                                                  "type": "recent destination",
                                                  "visible": true,
                                                  "x": p.x,
                                                  "y": p.y
                                              });
                });
            }
        }

        Column {
            /////////////////
            // Follow Me mode
            id: columnFollow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: styler.themePaddingMedium
            visible: followMe

            ListItemLabel {
                color: styler.themeHighlightColor
                text: app.tr("Follow the movement and show just in time information")
                truncMode: truncModes.none
                wrapMode: Text.WordWrap
            }

            ToolItemPL {
                id: beginFollowMeItem
                icon.iconHeight: styler.themeIconSizeMedium
                icon.iconName: app.mode === modes.followMe ? styler.iconStop : styler.iconStart
                text: app.mode === modes.followMe ? app.tr("Stop") : app.tr("Begin")
                width: columnFollow.width
                onClicked: {
                    if (app.mode === modes.followMe) {
                        app.navigator.followMe = false;
                        app.showMap();
                    } else {
                        app.navigator.clearRoute();
                        app.navigator.followMe = true;
                        app.hideMenu(); // there is no info panel, follow me mode starts and is using hidden menu
                    }
                }
            }

            FormLayoutPL {
                spacing: styler.themePaddingMedium

                ComboBoxPL {
                    description: app.tr("Select mode of transportation. Only applies when Pure Maps is in " +
                                        "follow me mode.")
                    label: app.tr("Mode of transportation")
                    model: [ app.tr("Car"), app.tr("Bicycle"), app.tr("Foot") ]
                    property string  value: "car"
                    property var     values: ["car", "bicycle", "foot"]
                    Component.onCompleted: {
                        var v = app.conf.followMeTransportMode;
                        currentIndex = Math.max(0, values.indexOf(v));
                        value = values[currentIndex];
                    }
                    onCurrentIndexChanged: {
                        value = values[currentIndex]
                        app.conf.set("follow_me_transport_mode", value);
                    }
                }
            }

            // Follow Me mode: done
            ///////////////////////

        }

        Timer {
            // timer is used to ensure that all property handlers by
            // page stacks of different platforms are fully processed
            // (such as canNavigateForward, for example) before trying
            // to calculate the route
            id: autoRouteTimer
            interval: 1 // arbitrary small value (in ms)
            running: false
            repeat: false
            onTriggered: app.pages.navigateForward()
        }
    }

    Component.onCompleted: {
        followMe = (app.mode === modes.followMe)
        if (!page.from) {
            page.from = app.getPosition();
            page.fromText = app.tr("Current position");
        }
        updateRouter();
        columnRouter.addSettings();
    }

    on_AutoRouteFlagChanged: routeAutomatically()
    onCanNavigateForwardChanged: routeAutomatically()

    onFollowMeChanged: {
        columnRouter.addSettings();
        routeAutomatically();
    }

    onPageStatusActive: {
        var uri = Qt.resolvedUrl(py.evaluate("poor.app.router.results_qml_uri"));
        app.pushAttached(uri);
        // check if this page is made active for adjusting route settings
        if (autoRoute) autoRoute = false;
        if (_autoRouteFlag === 0) _autoRouteFlag = 1;
    }

    function getLocations() {
        var routePoints = []
        if (from && fromText)
            routePoints.push( { "x": from[0], "y": from[1],
                                 "text": fromText } );
        if (waypointsEnabled)
            for (var i=0; i < waypoints.count; ++i)
                if (waypoints.get(i).set)
                    routePoints.push({ "destination": waypoints.get(i).destination,
                                         "x": waypoints.get(i).x, "y": waypoints.get(i).y,
                                         "text": waypoints.get(i).text });
        if (to && toText)
            routePoints.push({ "x": to[0], "y": to[1], "text": toText });

        // update current position if needed
        for (var i=0; i < routePoints.length; i++)
            if (routePoints[i]["text"] === app.tr("Current position")) {
                var p = app.getPosition();
                routePoints[i]["x"] = p[0];
                routePoints[i]["y"] = p[1];
            }

        return routePoints;
    }

    function routeAutomatically() {
        if (followMe || !canNavigateForward || !autoRouteSupported) return;
        if (_autoRouteFlag === 1) {
            autoRoute = true;
            _autoRouteFlag = 2;
            autoRouteTimer.start();
        }
    }

    function saveDestination() {
        for (var i=0; i < _destinationsNotForSave.length; i++)
            if (toText === _destinationsNotForSave[i].toText &&
                    Math.abs(to[0]-_destinationsNotForSave[i].x) < 1e-8 &&
                    Math.abs(to[1]-_destinationsNotForSave[i].y) < 1e-8)
                return false;

        if (!to || !toText)
            return false;

        var d = {
            'text': toText,
            'x': to[0],
            'y': to[1]
        };
        py.call_sync("poor.app.history.add_destination", [d]);
        return true;
    }

    function saveLocations() {
        py.call_sync("poor.app.history.add_route", [{"locations": getLocations(), "optimized": optimized}]);
    }

    function updateRouter() {
        page.routerName = py.evaluate("poor.app.router.name");
        page.autoRouteSupported = py.evaluate("poor.app.router.auto_route");
        page.fromNeeded = py.evaluate("poor.app.router.from_needed");
        page.toNeeded = py.evaluate("poor.app.router.to_needed");
    }

}
