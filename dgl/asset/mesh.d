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

module dgl.asset.mesh;

import std.stdio;

import dlib.core.memory;
import dlib.container.array;
import dlib.geometry.triangle;

import derelict.opengl.gl;
import derelict.opengl.glext;

import dgl.core.interfaces;
import dgl.graphics.material;
import dgl.asset.scene;

class FaceGroup: ManuallyAllocatable
{
    DynamicArray!Triangle tris;
    uint displayList;
    int materialIndex;
    Material material;

    void free()
    {
        if (glIsList(displayList))
            glDeleteLists(displayList, 1);
        tris.free();
        Delete(this);
    }

    mixin ManualModeImpl;
}

class Mesh: Drawable
{
    int id;
    string name;
    Triangle[] tris;
    DynamicArray!FaceGroup fgroups;

    this(Triangle[] tris)
    {
        this.tris = tris;
    }

    void genFaceGroups(Scene scene)
    {
        // Assign tris to corresponding face groups
        foreach(tri; tris)
        {
            int m = tri.materialIndex;
            auto fg = getFaceGroupByMaterialId(m);
            fg.tris.append(tri);
        }

        // Assign materials to face groups 
        // and create display lists for them 
        foreach(fg; fgroups.data)
        {
            if (fg.materialIndex != -1)
                fg.material = scene.getMaterialById(fg.materialIndex);
            fg.displayList = glGenLists(1);
            glNewList(fg.displayList, GL_COMPILE);
            drawTris(fg.tris.data);
            glEndList();
        }
    }

    FaceGroup getFaceGroupByMaterialId(int m)
    {
        foreach(i, fg; fgroups.data)
        {
            if (fg.materialIndex == m)
                return fgroups.data[i];
        }

        FaceGroup fg = New!FaceGroup();
        fg.materialIndex = m;
        fgroups.append(fg);
        return fg;
    }

    void drawTris(Triangle[] triangles)
    {
        foreach(tri; triangles)
        {
            glBegin(GL_TRIANGLES);
            // TODO: generate tangent vectors
            // (store them in Triangle.tangent, pass via vertex colors)
            // TODO: add possibility to select between 
            // per face normals and per vertex normals
            //glNormal3fv(tri.normal.arrayof.ptr);

            glNormal3fv(tri.n[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[0].arrayof.ptr);
            glVertex3fv(tri.v[0].arrayof.ptr);
            
            glNormal3fv(tri.n[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[1].arrayof.ptr);
            glVertex3fv(tri.v[1].arrayof.ptr);
            
            glNormal3fv(tri.n[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[2].arrayof.ptr);
            glVertex3fv(tri.v[2].arrayof.ptr);
            glEnd();
        }
    }

    override void draw(double dt)
    {
        foreach(fg; fgroups.data)
        {
            if (fg.material)
                fg.material.bind(dt);

            if (glIsList(fg.displayList))
                glCallList(fg.displayList);

            if (fg.material)
                fg.material.unbind();
        }
    }

    void free()
    {
        if (name.length)
            Delete(name);
        Delete(tris);
        foreach(fg; fgroups.data)
            fg.free();
        fgroups.free();
        Delete(this);
    }

    mixin ManualModeImpl;
}


