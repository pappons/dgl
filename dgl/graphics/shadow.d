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

module dgl.graphics.shadow;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;

import dlib.core.memory;
import dlib.container.array;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.utils;

import dgl.core.interfaces;
import dgl.graphics.scene;
import dgl.graphics.material;

class ShadowMap: Drawable
{
    Scene castScene;
    Scene receiveScene;

    GLuint depthBuffer;
    Matrix4x4f lightProjectionMatrix;
    Matrix4x4f lightViewMatrix;
    Vector4f lightPosition = Vector4f(0.0f, -1.0f, 0.0f, 0.0f);

    Matrix4x4f biasMatrix;

    Vector4f white = Vector4f(1.0f, 1.0f, 1.0f, 1.0f);
    Vector4f c = Vector4f(0.0f, 0.1f, 0.2f, 1.0f);
    Vector4f black = Vector4f(0.0f, 0.0f, 0.0f, 0.0f);

    uint width, height;
    GLint[4] viewport;

    float ofsFactor = 4.7;
    float ofsUnits = 5.3;

	bool useShader = true;

    this(uint w, uint h)
    {
        width = w;
        height = h;

        glDepthFunc(GL_LEQUAL);
        glEnable(GL_DEPTH_TEST);

        glGenTextures(1, &depthBuffer);
        glBindTexture(GL_TEXTURE_2D, depthBuffer);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); //GL_NEAREST for sharp edges
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); //GL_NEAREST for sharp edges
        //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        //Vector4f wrapColor = Vector4f(1, 1, 1, 1);
        //glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, wrapColor.arrayof.ptr);

        //Enable shadow comparison
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE_ARB, GL_COMPARE_R_TO_TEXTURE_ARB);
        //Shadow comparison should be true (i.e. not in shadow) if r <= texture
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_FUNC_ARB, GL_LEQUAL);
        //Shadow comparison should generate an INTENSITY result
        glTexParameteri(GL_TEXTURE_2D, GL_DEPTH_TEXTURE_MODE, GL_INTENSITY);

        glTexImage2D(GL_TEXTURE_2D, 0,
            GL_DEPTH_COMPONENT, width, height, 0,
            GL_DEPTH_COMPONENT, GL_UNSIGNED_BYTE, null);

        glLoadIdentity();
        glOrtho(-13, 13, -13, 13, -100.0f, 100.0f);
        glGetFloatv(GL_MODELVIEW_MATRIX, lightProjectionMatrix.arrayof.ptr);
        glLoadIdentity();

        Vector3f v1 = Vector3f(1, -1, 1).normalized;
        Vector3f v2 = cross(v1, Vector3f(0, 1, 0));
        up = cross(v2, v1);
    }

    Vector3f up;

    void draw(double dt)
    {
        glPushMatrix();
        glLoadIdentity();
        Vector3f toVector = Vector3f(lightPosition.x + 1, -1, lightPosition.z + 1);
        gluLookAt(lightPosition.x, 0, lightPosition.z,
            toVector.x, toVector.y, toVector.z,
            up.x, up.y, up.z);
        glGetFloatv(GL_MODELVIEW_MATRIX, lightViewMatrix.arrayof.ptr);
        glPopMatrix();

        //lightViewMatrix = directionToMatrix(Vector3f(0, -1, 0).normalized);

        //Vector3f posVector = Vector3f(lightPosition.x, 20.0f, lightPosition.z);
        //Vector3f toVector = Vector3f(lightPosition.x, 0.0f, lightPosition.z);
        //lightViewMatrix = lookAtMatrix(Vector3f(0, -1, 0), Vector3f(0, 0, 0), Vector3f(0, 1, 0));
            //translationMatrix(Vector3f(lightPosition));
            //rotationMatrix(2, degtorad(-90.0f));

        renderDepthBuffer(dt);

        glClear(GL_DEPTH_BUFFER_BIT);

        //Use dim light to represent shadowed areas
        glLightfv(GL_LIGHT7, GL_POSITION, lightPosition.arrayof.ptr);
        glLightfv(GL_LIGHT7, GL_AMBIENT, c.arrayof.ptr);
        glLightfv(GL_LIGHT7, GL_DIFFUSE, c.arrayof.ptr);
        glLightfv(GL_LIGHT7, GL_SPECULAR, black.arrayof.ptr);
        glEnable(GL_LIGHT7);
        glEnable(GL_LIGHTING);

        //matUseShaders = false;

        if (receiveScene)
        {
            receiveScene.lighted = false;
            dgl.graphics.material.useDimLight = true;
            receiveScene.draw(dt);
        }
        if (castScene)
        {
            castScene.lighted = false;
            dgl.graphics.material.useDimLight = true;
            castScene.draw(dt);
        }

        //Draw with bright light
        glLightfv(GL_LIGHT7, GL_DIFFUSE, white.arrayof.ptr);
        glLightfv(GL_LIGHT7, GL_SPECULAR, white.arrayof.ptr);
        glDisable(GL_LIGHT7);
        glDisable(GL_LIGHTING);

        //Bind & enable shadow map texture
        glActiveTextureARB(GL_TEXTURE3_ARB);
        bindDepthBuffer();

        // Calculate texture matrix for projection
        // This matrix takes us from eye space to the light's clip space
        // It is postmultiplied by the inverse of the current view matrix when specifying texgen
        //Matrix4x4f textureMatrix = biasMatrix * lightProjectionMatrix * lightViewMatrix;
        glMatrixMode(GL_TEXTURE);
        glPushMatrix();
        glLoadIdentity();
        //glLoadMatrixf(textureMatrix.arrayof.ptr);
        glTranslatef(0.5f, 0.5f, 0.5f); // remap from [-1,1]^2 to [0,1]^2
        glScalef(0.5f, 0.5f, 0.5f);
        glMultMatrixf(lightProjectionMatrix.arrayof.ptr);
        glMultMatrixf(lightViewMatrix.arrayof.ptr);
        glMatrixMode(GL_MODELVIEW);

        auto ide = Matrix4x4f.identity;

        //Set up texture coordinate generation.
        glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
        glTexGenfv(GL_S, GL_EYE_PLANE, ide.getRow(0).arrayof.ptr);
        glEnable(GL_TEXTURE_GEN_S);

        glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
        glTexGenfv(GL_T, GL_EYE_PLANE, ide.getRow(1).arrayof.ptr);
        glEnable(GL_TEXTURE_GEN_T);

        glTexGeni(GL_R, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
        glTexGenfv(GL_R, GL_EYE_PLANE, ide.getRow(2).arrayof.ptr);
        glEnable(GL_TEXTURE_GEN_R);

        glTexGeni(GL_Q, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR);
        glTexGenfv(GL_Q, GL_EYE_PLANE, ide.getRow(3).arrayof.ptr);
        glEnable(GL_TEXTURE_GEN_Q);

        //Set alpha test to discard false comparisons
        //glAlphaFunc(GL_GREATER, 0.7f);
        //glEnable(GL_ALPHA_TEST);

        glActiveTextureARB(GL_TEXTURE0_ARB);

        glEnable(GL_POLYGON_OFFSET_FILL);
        glPolygonOffset(ofsFactor, ofsUnits);

        //matUseShaders = true;

        if (castScene)
        {
            castScene.lighted = true;
            dgl.graphics.material.useDimLight = false;
            castScene.draw(dt);
        }
        if (receiveScene)
        {
            receiveScene.lighted = true;
            dgl.graphics.material.useDimLight = false;
            receiveScene.draw(dt);
        }

        //glPolygonOffset(0, 0);

        //Disable textures and texgen
        glActiveTextureARB(GL_TEXTURE3_ARB);
        unbindDepthBuffer();

        glDisable(GL_TEXTURE_GEN_S);
        glDisable(GL_TEXTURE_GEN_T);
        glDisable(GL_TEXTURE_GEN_R);
        glDisable(GL_TEXTURE_GEN_Q);

        glMatrixMode(GL_TEXTURE);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);

        glActiveTextureARB(GL_TEXTURE0_ARB);

        //Restore other states
        glDisable(GL_LIGHTING);
        glDisable(GL_ALPHA_TEST);
    }

    void renderDepthBuffer(double dt)
    {
        //glCullFace(GL_FRONT);
        glShadeModel(GL_FLAT);
        glColorMask(0, 0, 0, 0);

        glGetIntegerv(GL_VIEWPORT, viewport.ptr);
        glViewport(0, 0, width, height);

        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadMatrixf(lightProjectionMatrix.arrayof.ptr);
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadMatrixf(lightViewMatrix.arrayof.ptr);

        //matUseShaders = false;

        // Draw the scene
        if (castScene)
        {
		    dgl.graphics.material.useDimLight = true;
            //castScene.setMaterialsUseShaders(false);
            castScene.draw(dt);
			dgl.graphics.material.useDimLight = false;
        }

        glPopMatrix();
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);

        //Read the depth buffer into the shadow map texture
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, depthBuffer);
        glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, width, height);
        glBindTexture(GL_TEXTURE_2D, 0);
        glDisable(GL_TEXTURE_2D);

        glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);

        //restore states
        //glCullFace(GL_BACK);
        glShadeModel(GL_SMOOTH);
        glColorMask(1, 1, 1, 1);
    }

    void free()
    {
        Delete(this);
    }

    ~this()
    {
        if (glIsTexture(depthBuffer))
            glDeleteTextures(1, &depthBuffer);
    }

    void bindDepthBuffer()
    {
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, depthBuffer);
    }

    void unbindDepthBuffer()
    {
        glBindTexture(GL_TEXTURE_2D, 0);
        glDisable(GL_TEXTURE_2D);
    }
}
