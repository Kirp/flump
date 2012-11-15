//
// Flump - Copyright 2012 Three Rings Design

package flump.export {

import flash.desktop.NativeApplication;
import flash.display.NativeWindow;
import flash.events.Event;
import flash.events.InvokeEvent;
import flash.filesystem.File;
import flash.net.FileFilter;

import flump.xfl.XflLibrary;

import spark.components.Window;

import starling.display.Sprite;

import com.threerings.util.Arrays;
import com.threerings.util.F;
import com.threerings.util.Log;

public class FlumpApp
{
    public static const NA :NativeApplication = NativeApplication.nativeApplication;

    public static function get app () :FlumpApp {
        return _app;
    }

    public function FlumpApp () {
        if (_app != null) {
            throw new Error("FlumpApp is a singleton");
        }
        _app = this;
    }

    public function run () :void {
        Log.setLevel("", Log.INFO);

        var launched :Boolean = false;
        NA.addEventListener(InvokeEvent.INVOKE, function (event :InvokeEvent) :void {
            if (event.arguments.length > 0) {
                // A project file has been double-clicked. Open it.
                openProject(new File(event.arguments[0]));
            }

            if (!launched) {
                launched = true;
                if (FlumpSettings.projectWindowSettings.length > 0) {
                    // The app has been launched directly. Open the previously-opened projects.
                    for each (var pws :ProjectWindowSettings in FlumpSettings.projectWindowSettings) {
                        var project :ProjectController = openProject(new File(pws.configFilePath));
                        project.win.nativeWindow.x = pws.windowX;
                        project.win.nativeWindow.y = pws.windowY;
                    }
                } else {
                    showOpenProjectDialog();
                }
            }
        });

        // When we quit, save the list of currently-open projects
        NA.addEventListener(Event.EXITING, function (..._) :void {
            var projectWindowSettings :Array = [];
            for each (var project :ProjectController in _projects) {
                if (project.configFile != null) {
                    projectWindowSettings.push(ProjectWindowSettings.fromProject(project));
                }
            }

            FlumpSettings.projectWindowSettings = projectWindowSettings;
        });
    }

    public function showPreviewWindow (lib :XflLibrary) :void {
        if (_previewController == null || _previewWindow.closed || _previewControls.closed) {
            _previewWindow = new PreviewWindow();
            _previewControls = new PreviewControlsWindow();
            _previewWindow.started = function (container :Sprite) :void {
                _previewController = new PreviewController(lib, container, _previewWindow,
                    _previewControls);
            }

            _previewWindow.open();
            _previewControls.open();

            preventWindowClose(_previewWindow.nativeWindow);
            preventWindowClose(_previewControls.nativeWindow);

        } else {
            _previewController.lib = lib;
            _previewControls.activate();
            _previewWindow.activate();
        }

        _previewWindow.orderToFront();
        _previewControls.orderToFront();
    }

    public function openProject (configFile :File = null) :ProjectController {
        // This project may already be open.
        for each (var ctrl :ProjectController in _projects) {
            if (ctrl.configFile != null && ctrl.configFile.nativePath == configFile.nativePath) {
                ctrl.win.activate();
                return ctrl;
            }
        }

        var controller :ProjectController = new ProjectController(configFile);
        controller.win.addEventListener(Event.CLOSE, F.callbackOnce(closeProject, controller));
        _projects.push(controller);

        return controller;
    }

    public function showOpenProjectDialog () :void {
        var file :File = new File();
        file.addEventListener(Event.SELECT, function (..._) :void {
            FlumpApp.app.openProject(file);
        });
        file.browseForOpen("Open Flump Project", [
            new FileFilter("Flump project (*.flump)", "*.flump") ]);
    }

    protected function closeProject (controller :ProjectController) :void {
        Arrays.removeFirst(_projects, controller);
    }

    // Causes a window to be hidden, rather than closed, when its close box is clicked
    protected static function preventWindowClose (window :NativeWindow) :void {
        window.addEventListener(Event.CLOSING, function (e :Event) :void {
            e.preventDefault();
            window.visible = false;
        });
    }

    protected var _projects :Array = [];

    protected var _previewController :PreviewController;
    protected var _previewWindow :PreviewWindow;
    protected var _previewControls :PreviewControlsWindow;

    protected static var _app :FlumpApp;
}
}