/*
Copyright (c) 2013-2015 Timur Gafarov 

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

module dgl.graphics.material;

import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;

import dlib.core.memory;
import dlib.image.color;
	
import dgl.core.interfaces;
import dgl.graphics.texture;
import dgl.graphics.shader;

enum TextureCombinerMode: ushort
{
    Blend = 0,
    Modulate = 1,
    Add = 2,
    Subtract = 3,
    Dot3 = 4,
    Dot3Alpha = 5
}

// TODO: shaders
class Material: Modifier
{
    int id;
    string name;

    Color4f ambientColor;
    Color4f diffuseColor;
    Color4f specularColor;
    Color4f emissionColor;
    float shininess;
    Shader shader;
    Texture[8] textures;
    ushort[8] texBlendMode;
    bool shadeless = false;

    this()
    {
        ambientColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        diffuseColor = Color4f(0.8f, 0.8f, 0.8f, 1.0f);
        specularColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        emissionColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        shininess = 64.0f;
    }

    @property uint numTextures()
    {
        uint res = 0;
        foreach(t; textures)
            if (t !is null) res++;
        return res;
    }

    void bind(double dt)
    {
        glEnable(GL_LIGHTING);
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambientColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuseColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, specularColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, emissionColor.arrayof.ptr);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, &shininess);

        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        if (shadeless)
        {
            glDisable(GL_LIGHTING);
            glColor4f(diffuseColor.r, diffuseColor.g, diffuseColor.b, diffuseColor.a);
        }

        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + i);
                tex.bind(dt);
            }
        }

        if (shader)
            shader.bind(dt);
    }

    void unbind()
    {
        if (shader)
            shader.unbind();

        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + i);
                tex.unbind();
            }
        }

        glActiveTextureARB(GL_TEXTURE0_ARB);
		
        if (shadeless)
            glEnable(GL_LIGHTING);
    }

    override string toString()
    {
        return format(
            "id = %s\n"
            "name = %s\n"
            "ambientColor = %s\n"
            "diffuseColor = %s\n"
            "specularColor = %s\n"
            "emissionColor = %s",
            id,
            name,
            ambientColor,
            diffuseColor,
            specularColor,
            emissionColor
        );
    }

    void free()
    {
        if (name.length)
            Delete(name);
        Delete(this);
    }
    
    mixin ManualModeImpl;
}

