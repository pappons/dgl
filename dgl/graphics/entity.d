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

module dgl.graphics.entity;

import std.string;

import derelict.opengl.gl;
import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.quaternion;
import dlib.geometry.aabb;
import dgl.core.interfaces;
import dgl.graphics.object3d;
import dgl.graphics.mesh;
import dgl.dml.dml;

class Entity: Object3D
{
    int id;
    string name;
    uint type = 0;
    int materialId = -1;
    int meshId = -1;
    bool debugDraw = true;

    Drawable drawable;
    Modifier modifier;

    Vector3f position;
    Quaternionf rotation;
    Vector3f scaling;

    Matrix4x4f transformation;

    DMLData props;
    
    this(Drawable drw, Vector3f pos)
    {
        position = pos;
        rotation = Quaternionf.identity;
        scaling = Vector3f(1, 1, 1);
        transformation = translationMatrix(position);
        drawable = drw;
    }
    
    this(Vector3f pos)
    {
        position = pos;
        rotation = Quaternionf.identity;
        scaling = Vector3f(1, 1, 1);
        transformation = translationMatrix(position);
        drawable = null;
    }

    this()
    {
        position = Vector3f(0, 0, 0);
        rotation = Quaternionf.identity;
        scaling = Vector3f(1, 1, 1);
        transformation = translationMatrix(position);
        drawable = null;
    }

    void setTransformation(Vector3f pos, Quaternionf rot, Vector3f scal)
    {
        position = pos;
        rotation = rot;
        scaling = scal;
        transformation = 
            translationMatrix(pos) *
            rot.toMatrix4x4 *
            scaleMatrix(scaling);
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }

    Quaternionf getRotation()
    {
        //Quaternionf rot;
        //rot.fromMatrix(transformation);
        //return rot;
        return rotation;
    }

    Vector3f getScaling()
    {
        //return transformation.scaling;
        return scaling;
    }
    
    override AABB getAABB()
    {
        return AABB(transformation.translation, Vector3f(1, 1, 1));
    }
    
    override void draw(double dt)
    {
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);            
        drawModel(dt);
        glPopMatrix();
    }

    void drawModel(double dt)
    {
        if (modifier !is null)
            modifier.bind(dt);
        if (drawable !is null)
        {
            Drawable3D drw3d = cast(Drawable3D)drawable;
            if (drw3d)
                drw3d.draw(this, dt);
            else
                drawable.draw(dt);
        }
        else if (debugDraw)
        {
            drawPoint();
        }
        if (modifier !is null)
            modifier.unbind();
    }

    void drawPoint()
    {
        glColor4f(1,1,1,1);
        glPointSize(5.0f);
        glBegin(GL_POINTS);
        glVertex3f(0, 0, 0);
        glEnd();
        glPointSize(1.0f);
    }

    override string toString()
    {
        return format(
            "type = %s\n"
            "materialId = %s\n"
            "meshId = %s\n"
            "position = %s\n"
            "rotation = %s\n"
            "scaling = %s",
            type,
            materialId,
            meshId,
            getPosition(),
            getRotation(),
            getScaling()
        );
    }

    void freeContent()
    {
        if (name.length)
            Delete(name);
        props.free();
    }
    
    override void free()
    {
        freeContent();
        Delete(this);
    }
    
    mixin ManualModeImpl;
}
