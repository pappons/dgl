/*
Copyright (c) 2015-2016 Timur Gafarov 

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

module dgl.graphics.ubershader;

import dlib.core.memory;
import dgl.core.api;
import dgl.core.event;
import dgl.graphics.material;
import dgl.graphics.shader;

private string _uberVertexShader = q{
    varying vec4 shadowCoord;
    varying vec3 position;
    varying vec3 n, t, b;
    varying vec3 E;
    uniform bool bumpEnabled;
        
    void main(void)
    {
        gl_TexCoord[0] = gl_MultiTexCoord0;
        gl_TexCoord[1] = gl_MultiTexCoord1;

        n = normalize(gl_NormalMatrix * gl_Normal);
        t = normalize(gl_NormalMatrix * gl_Color.xyz);
        b = cross(n, t);
        position = (gl_ModelViewMatrix * gl_Vertex).xyz;
        
        E = position;
        if (bumpEnabled)
        {
            E.x = dot(position, t);
            E.y = dot(position, b);
            E.z = dot(position, n);
        }
        E = -normalize(E);
        
        shadowCoord = gl_TextureMatrix[7] * (gl_ModelViewMatrix * gl_Vertex);
        
        gl_Position = ftransform();
    }
};

private string _uberFragmentShader = q{
    varying vec4 shadowCoord;
    varying vec3 position;
    varying vec3 n, t, b;
    varying vec3 E;
        
    uniform sampler2D dgl_Texture0;
    uniform sampler2D dgl_Texture1;
    uniform sampler2D dgl_Texture2;
    uniform sampler2D dgl_Texture7;
    
    uniform bool shadeless;
    const bool shadowEnabled = true;
    uniform bool textureEnabled;
    uniform bool bumpEnabled;
    uniform bool parallaxEnabled;
    uniform bool glowMapEnabled;
    uniform bool rimLightEnabled;
    uniform bool fogEnabled;
    uniform float dgl_ShadowMapSize;
    
    const float parallaxScale = 0.06;
    const float parallaxBias = -0.03;
    const float lightRadiusSqr = 9.0;
    const float shadowBrightness = 0.4;
    const float edgeWidth = 0.2;
    
    float texture2DCompare(sampler2D depths, vec2 uv, float compare)
    {
        float depth = texture2D(depths, uv).z;
        return (depth < compare)? 0.0 : 1.0;
    }
    
    float texture2DShadowLerp(sampler2D depths, vec2 uv, float compare)
    {
        vec2 texelSize = vec2(1.0) / dgl_ShadowMapSize;
        vec2 f = fract(uv * dgl_ShadowMapSize + 0.5);
        vec2 centroidUV = floor(uv * dgl_ShadowMapSize + 0.5) / dgl_ShadowMapSize;

        float lb = texture2DCompare(depths, centroidUV + texelSize * vec2(0.0, 0.0), compare);
        float lt = texture2DCompare(depths, centroidUV + texelSize * vec2(0.0, 1.0), compare);
        float rb = texture2DCompare(depths, centroidUV + texelSize * vec2(1.0, 0.0), compare);
        float rt = texture2DCompare(depths, centroidUV + texelSize * vec2(1.0, 1.0), compare);
        float a = mix(lb, lt, f.y);
        float b = mix(rb, rt, f.y);
        float c = mix(a, b, f.x);
        return c;
    }
    
    float edgeBias(float value, float b)
    {
        return (b > 0.0)? pow(value, log2(b) / log2(0.5)) : 0.0;
    }

    void main(void) 
    {
        vec2 texCoords = gl_TexCoord[0].st;
        
        if (shadeless)
        {
            gl_FragColor = textureEnabled? texture2D(dgl_Texture0, texCoords) : gl_FrontMaterial.diffuse;
            return;
        }
        
        // Fog term
        float fogDistance = gl_FragCoord.z / gl_FragCoord.w;
        float fogFactor = fogEnabled? 
            clamp((gl_Fog.end - fogDistance) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0) :
            1.0;
        
        // Shadow term
        float shadow = 1.0;
        if (shadowEnabled)
        {
            shadow = 0.0;
            vec4 shadowCoordinateWdivide = shadowCoord / shadowCoord.w ;
            if (shadowCoord.w > 0.0)
            {
                shadowCoordinateWdivide.z -= 0.0002; //*=0.9999;
                shadow = texture2DShadowLerp(dgl_Texture7, shadowCoordinateWdivide.st, shadowCoordinateWdivide.z);
            }
            shadow += shadowBrightness;
        }
        
        // Parallax mapping
        if (parallaxEnabled)
        {
            vec2 eye2 = vec2(E.x, -E.y);
            float height = texture2D(dgl_Texture1, texCoords).a; 
            height = height * parallaxScale + parallaxBias;
            texCoords = texCoords + (height * eye2);
        }
        
        vec3 nn = normalize(n);
        vec3 tn = normalize(t);
        vec3 bn = normalize(b);
        
        // Normal mapping
        vec3 N = bumpEnabled? normalize(2.0 * texture2D(dgl_Texture1, texCoords).rgb - 1.0) : nn;
    
        // Texture
        vec4 tex = textureEnabled? texture2D(dgl_Texture0, texCoords) : vec4(1.0, 1.0, 1.0, 1.0);
        
        // Emission term
        vec4 emit = glowMapEnabled?
            texture2D(dgl_Texture2, texCoords) * gl_FrontMaterial.emission.w :
            vec4(0.0, 0.0, 0.0, 1.0);
        
        vec3 directionToLight;
        float distanceToLight;
        float attenuation = 1.0; 
        vec3 L;
            
        vec4 col_d = vec4(0.0, 0.0, 0.0, 1.0);
        vec4 col_s = vec4(0.0, 0.0, 0.0, 1.0);
        vec4 col_r = vec4(0.0, 0.0, 0.0, 1.0);

        float diffuse;
        float specular;
        
        vec3 H;
        float NL;
        float NH;
        
        float edgeScale;
        float rim = 0.0;

        vec4 Cr = vec4(0.01, 0.1, 0.1, 1.0);
        const vec4 one = vec4(1.0, 1.0, 1.0, 1.0);

        for (int i = 0; i < 4; i++)
        {
            if (gl_LightSource[i].position.w < 2.0)
            {
                vec4 Md = gl_FrontMaterial.diffuse;
                vec4 Ms = gl_FrontMaterial.specular;
                vec4 Ld = gl_LightSource[i].diffuse; 
                vec4 Ls = gl_LightSource[i].specular;
            
                if (gl_LightSource[i].position.w > 0.0)
                {
                    vec3 positionToLightSource = vec3(gl_LightSource[i].position.xyz - position);
                    distanceToLight = length(positionToLightSource);
                    directionToLight = normalize(positionToLightSource);
            
                    attenuation = clamp(1.0 - distanceToLight/lightRadiusSqr, 0.0, 1.0);
                }
                else
                {
                    directionToLight = gl_LightSource[i].position.xyz;
                    attenuation = 1.0;
                }
                
                L = bumpEnabled? 
                    vec3(dot(directionToLight, tn),
                         dot(directionToLight, bn),
                         dot(directionToLight, nn)) : 
                    directionToLight;
                
                // Diffuse term
                diffuse = clamp(dot(N, L), 0.0, 1.0); // Lambert
                
                // Edge term
                rim = rimLightEnabled? 
                    max(0.0, edgeBias(1.0 - dot(E, N), edgeWidth)):
                    0.0;
                
                // Specular term
                H = normalize(L + E);
                NH = dot(N, H);
                specular = pow(max(NH, 0.0), 3.0 * gl_FrontMaterial.shininess); // Blinn-Phong

                col_d += Md*Ld*diffuse*attenuation;
                col_s += Ms*Ls*specular*attenuation;
                col_r += Cr*rim*attenuation * (1.0 - diffuse);
            }
        }
/*
        col_s *= 0.9;
        col_d *= 0.9;
        col_r *= 0.9;
*/
        vec4 finalColor = emit + (tex * gl_FrontMaterial.ambient + tex * col_d + col_s + col_r) * shadow;
        gl_FragColor = mix(gl_Fog.color, finalColor, fogFactor);
        
        gl_FragColor.a = tex.a;
    }
};

class UberShader: Shader
{   
    bool shadeless = false;
    bool textureEnabled = false;
    bool bumpEnabled = false;
    bool parallaxEnabled = false;
    bool glowMapEnabled = false;
    bool rimLightEnabled = false;
    bool fogEnabled = false;
    float shininess = 32.0f;
    
    this()
    {
        super(_uberVertexShader, _uberFragmentShader);
    }
    
    override void bind(double dt)
    {
        super.bind(dt);
        glUniform1i(glGetUniformLocation(shaderProg, "shadeless"), shadeless);
        glUniform1i(glGetUniformLocation(shaderProg, "textureEnabled"), textureEnabled);
        glUniform1i(glGetUniformLocation(shaderProg, "bumpEnabled"), bumpEnabled);
        glUniform1i(glGetUniformLocation(shaderProg, "parallaxEnabled"), parallaxEnabled);
        glUniform1i(glGetUniformLocation(shaderProg, "glowMapEnabled"), glowMapEnabled);
        glUniform1i(glGetUniformLocation(shaderProg, "rimLightEnabled"), rimLightEnabled);
        glUniform1i(glGetUniformLocation(shaderProg, "fogEnabled"), fogEnabled);
    }
    
    override void unbind()
    {
        super.unbind();
    }
}

