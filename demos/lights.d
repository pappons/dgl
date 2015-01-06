/*
Copyright (c) 2015 Timur Gafarov 

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

module lights;

import std.stdio;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glext;
import derelict.opengl.glu;
import derelict.freetype.ft;

import dlib.math.vector;
import dlib.math.affine;
import dlib.image.color;

import dgl.core.application;
import dgl.core.layer;
import dgl.core.drawable;
import dgl.vfs.vfs;
import dgl.vfs.file;
import dgl.ui.i18n;
import dgl.ui.ftfont;
import dgl.ui.textline;
import dgl.scene.tbcamera;
import dgl.templates.freeview;
import dgl.graphics.axes;
import dgl.graphics.lamp;
import dgl.graphics.shapes;

import dgl.graphics.light;
import dgl.graphics.lightmanager;
import dgl.scene.obj3d;

class DynamicObject: Object3D
{
    Drawable drawable;
    Vector3f position;

    this(Vector3f position, Drawable drawable)
    {
        this.position = position;
        this.drawable = drawable;
    }

    void translate(Vector3f trans)
    {
        position += trans;
    }
    
    override Vector3f getPosition()
    {
        return position;
    }

    override void draw(double dt)
    {
        glPushMatrix();
        glTranslatef(position.x, position.y, position.z);
        drawable.draw(dt);
        glPopMatrix();
    }

    override void free() {}
}

class LightApp: Application
{
    alias eventManager this;

    FreeviewLayer layer3d;
    Layer layer2d;

    VirtualFileSystem vfs;

    FreeTypeFont font;
    TextLine fpsText;

    LightManager lm;

    DynamicObject obj;

    this()
    {
        super(640, 480, "Virtual Lights Demo");

        clearColor = Color4f(0.2f, 0.2f, 0.2f);

        layer3d = new FreeviewLayer(videoWidth, videoHeight, 1);
        layer3d.alignToWindow = true;
        layer3d.drawAxes = false;
        addLayer(layer3d);
        eventManager.setGlobal("camera", layer3d.camera);

        layer3d.addDrawable(new Axes());

        vfs = new VirtualFileSystem();

        lm = new LightManager();
        lm.lightsVisible = true;
        layer3d.addDrawable(lm);
        
        foreach(y; 0..10)
        foreach(x; 0..10)
        {
            auto col = Color4f((randomUnitVector3!float + 1.0f).normalized);
            lm.addLight(pointLight(
                Vector3f(x*30, 5, y*30), 
                col, 
                Color4f(0.1f, 0.1f, 0.1f, 1.0f),
                0.0f, 0.5f, 0.01f));
        }

        ShapeSphere sphere = new ShapeSphere(3.0f);
        obj = new DynamicObject(Vector3f(0,0,0), sphere);
        lm.objects ~= obj;

        layer2d = addLayer2D(-1);
        layer2d.alignToWindow = true;

        font = new FreeTypeFont("data/fonts/droid/DroidSans.ttf", 27);

        fpsText = new TextLine(font, "", Vector2f(10, 10));
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

        layer3d.camera.setTarget(-obj.position);

        float speed = 20.0f * eventManager.deltaTime;
        if (key_pressed[SDLK_UP]) obj.translate(Vector3f(0,0,1) * speed);
        if (key_pressed[SDLK_DOWN]) obj.translate(Vector3f(0,0,-1) * speed);
        if (key_pressed[SDLK_LEFT]) obj.translate(Vector3f(1,0,0) * speed);
        if (key_pressed[SDLK_RIGHT]) obj.translate(Vector3f(-1,0,0) * speed);
    }
}

void loadLibraries()
{
    version(Windows)
    {
        enum sharedLibSDL = "SDL.dll";
        enum sharedLibFT = "freetype.dll";
    }
    version(linux)
    {
        enum sharedLibSDL = "./libsdl.so";
        enum sharedLibFT = "./libfreetype.so";
    }

    DerelictGL.load();
    DerelictGLU.load();
    DerelictSDL.load(sharedLibSDL);
    DerelictFT.load(sharedLibFT);
}

void main()
{
    loadLibraries();
    Locale.readLang("locale");
    auto app = new LightApp();
    app.run();
}