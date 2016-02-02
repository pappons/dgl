/*
Copyright (c) 2014-2016 Timur Gafarov

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

module dgl.graphics.mesh;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.container.array;
import dlib.math.vector;
import dlib.math.utils;
import dlib.geometry.triangle;

import derelict.opengl.gl;
import derelict.opengl.glext;

import dgl.core.interfaces;
import dgl.graphics.material;
import dgl.graphics.scene;

class FaceGroup
{
    DynamicArray!Triangle tris;
    uint displayList;
    int materialIndex;
    Material material;

    ~this()
    {
        if (glIsList(displayList))
            glDeleteLists(displayList, 1);
        tris.free();
    }
}

bool vectorsAlmostSame(Vector3f v1, Vector3f v2) nothrow
{
    return (v1 - v2).length < 0.001f;
}

int hasVector(ref DynamicArray!Vector3f arr, Vector3f vec)
{
    foreach(i, v; arr.data)
    {
        if (vectorsAlmostSame(v, vec))
            return cast(int)i;
    }
    return -1;
}

//__gshared bool generateTangentVectors = true;

class Mesh: Drawable
{
    int id;
    string name;
    Triangle[] tris;
    DynamicArray!FaceGroup fgroups;
    bool genTangents = true;

    this(Triangle[] tris)
    {
        this.tris = tris;
    }

    protected void generateTangents()
    {
        DynamicArray!Vector3f vertices;
        DynamicArray!Vector3f normals;
        DynamicArray!Vector2f texcoords;
        DynamicArray!(uint[3]) triangles;

        foreach(ref tri; tris)
        {
            uint[3] triangle;
            foreach(i; 0..3)
            {
                Vector3f v = tri.v[i];
                Vector3f n = tri.n[i];
                Vector2f t = tri.t1[i];

                //int vi = vertices.hasVector(v);

                //if (vi == -1)
                {
                    vertices.append(v);
                    normals.append(n);
                    texcoords.append(t);
                    triangle[i] = cast(uint)(vertices.length-1);
                }
                //else
                //{
                //    triangle[i] = vi;
                //}
            }
            triangles.append(triangle);
        }

        Vector3f[] sTan = New!(Vector3f[])(vertices.length);
        Vector3f[] tTan = New!(Vector3f[])(vertices.length);

        foreach(i, v; sTan)
        {
            sTan[i] = Vector3f(0.0f, 0.0f, 0.0f);
            tTan[i] = Vector3f(0.0f, 0.0f, 0.0f);
        }

        foreach(ref tri; triangles.data)
        {
            uint i0 = tri[0];
            uint i1 = tri[1];
            uint i2 = tri[2];

            Vector3f v0 = vertices.data[i0];
            Vector3f v1 = vertices.data[i1];
            Vector3f v2 = vertices.data[i2];

            Vector2f w0 = texcoords.data[i0];
            Vector2f w1 = texcoords.data[i1];
            Vector2f w2 = texcoords.data[i2];

            float x1 = v1.x - v0.x;
            float x2 = v2.x - v0.x;
            float y1 = v1.y - v0.y;
            float y2 = v2.y - v0.y;
            float z1 = v1.z - v0.z;
            float z2 = v2.z - v0.z;

            float s1 = w1[0] - w0[0];
            float s2 = w2[0] - w0[0];
            float t1 = w1[1] - w0[1];
            float t2 = w2[1] - w0[1];

            float r = (s1 * t2) - (s2 * t1);

            // Prevent division by zero
            if (r == 0.0f)
                r = 1.0f;

            float oneOverR = 1.0f / r;

            Vector3f sDir = Vector3f((t2 * x1 - t1 * x2) * oneOverR,
                                     (t2 * y1 - t1 * y2) * oneOverR,
                                     (t2 * z1 - t1 * z2) * oneOverR);
            Vector3f tDir = Vector3f((s1 * x2 - s2 * x1) * oneOverR,
                                     (s1 * y2 - s2 * y1) * oneOverR,
                                     (s1 * z2 - s2 * z1) * oneOverR);

            sTan[i0] += sDir;
            tTan[i0] += tDir;

            sTan[i1] += sDir;
            tTan[i1] += tDir;

            sTan[i2] += sDir;
            tTan[i2] += tDir;
        }

        Vector3f[] tangents = New!(Vector3f[])(vertices.length);

        // Calculate vertex tangent
        foreach(i, v; tangents)
        {
            Vector3f n = normals.data[i];
            Vector3f t = sTan[i];

            // Gram-Schmidt orthogonalize
            tangents[i] = (t - n * dot(n, t));
            tangents[i].normalize();

            // Calculate handedness
            //if (dot(cross(n, t), tTan[i]) < 0.0f)
	        //    tangents[i] = -tangents[i];
        }

        foreach(ti, ref tri; tris)
        foreach(i; 0..3)
        {
            tri.tg[i] = tangents[triangles.data[ti][i]];
        }

        Delete(sTan);
        Delete(tTan);
        Delete(tangents);
        vertices.free();
        normals.free();
        texcoords.free();
        triangles.free();
    }

    void genFaceGroups(MaterialLibrary matlib)
    {
        if (genTangents)
            generateTangents();
    
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
                fg.material = matlib.getMaterial(fg.materialIndex);
            fg.displayList = glGenLists(1);
            glNewList(fg.displayList, GL_COMPILE);
            drawTris(fg.tris.data);
            glEndList();
        }
    }

    protected FaceGroup getFaceGroupByMaterialId(int m)
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
        //glColor4f(1, 1, 1, 1);
        foreach(tri; triangles)
        {
            glBegin(GL_TRIANGLES);
            // TODO: add possibility to select between
            // per face normals and per vertex normals
            //glNormal3fv(tri.normal.arrayof.ptr);

            glNormal3fv(tri.n[0].arrayof.ptr);
            if (genTangents)
                glColor3fv(tri.tg[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[0].arrayof.ptr);
            glVertex3fv(tri.v[0].arrayof.ptr);

            glNormal3fv(tri.n[1].arrayof.ptr);
            if (genTangents)
                glColor3fv(tri.tg[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[1].arrayof.ptr);
            glVertex3fv(tri.v[1].arrayof.ptr);

            glNormal3fv(tri.n[2].arrayof.ptr);
            if (genTangents)
                glColor3fv(tri.tg[2].arrayof.ptr);
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

    void freeContent()
    {
        if (name.length)
            Delete(name);
        Delete(tris);
        foreach(fg; fgroups)
            Delete(fg);
        fgroups.free();
    }

    ~this()
    {
        freeContent();
    }
}
