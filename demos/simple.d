/*
Copyright (c) 2014-2015 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module simple;

import std.stdio;
import std.conv;

import derelict.sdl.sdl;
import derelict.opengl.gl;

import dlib.math.vector;
import dlib.image.color;

import dgl.core.application;
import dgl.core.layer;
import dgl.ui.ftfont;
import dgl.ui.textline;
import dgl.ui.i18n;
import dgl.templates.freeview;

class TestApp: Application
{
    alias eventManager this;
    FreeTypeFont font;
    TextLine fpsText;

    Layer layer3d;
    Layer layer2d;

    this()
    {
        super(640, 480, "DGL Test App");

        clearColor = Color4f(0.5f, 0.5f, 0.5f);

        layer3d = new FreeviewLayer(videoWidth, videoHeight);
        addLayer(layer3d);

        layer2d = addLayer2D();

        font = new FreeTypeFont("data/fonts/droid/DroidSans.ttf", 27);

        fpsText = new TextLine(font, localizef("FPS: %s", fps), Vector2f(10, 10));
        fpsText.alignment = Alignment.Left;
        fpsText.color = Color4f(1, 1, 1);
        layer2d.addDrawable(fpsText);
    }

    override void onQuit()
    {
        super.onQuit();
    }
    
    override void onKeyDown()
    {
        super.onKeyDown();
    }
    
    override void onMouseButtonDown()
    {
        super.onMouseButtonDown();
    }
    
    override void onUpdate()
    {
        super.onUpdate();

        fpsText.setText(localizef("FPS: %s", fps));
    }
}

void main()
{
    Locale.readLang("locale");
    auto app = new TestApp();
    app.run();
}

