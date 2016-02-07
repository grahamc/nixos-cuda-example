////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014-2015 NVIDIA Corporation.  All rights reserved.
//
// Please refer to the NVIDIA end user license agreement (EULA) associated
// with this source code for terms and conditions that govern your use of
// this software. Any use, reproduction, disclosure, or distribution of
// this software and related documentation outside the terms of the EULA
// is strictly prohibited.
//
////////////////////////////////////////////////////////////////////////////

#include <GLES3/gl31.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>

screen_window_t screen_window;
screen_context_t screen_context;

EGLDisplay eglDisplay = EGL_NO_DISPLAY;
EGLSurface eglSurface = EGL_NO_SURFACE;
EGLContext eglContext = EGL_NO_CONTEXT;

void error_exit(const char* format, ... )
{
    va_list args;
    va_start( args, format );
    vfprintf( stderr, format, args );
    va_end( args );
    exit(1); 
}

void CHECK_GLERROR()
{
    GLenum err = glGetError();

    if (err != GL_NO_ERROR)
    {
        fprintf(stderr, "[%s line %d] OpenGL Error: 0x%x ", __FILE__, __LINE__, err);

        switch (err)
        {
        case GL_INVALID_ENUM:
            fprintf(stderr, "(GL_INVALID_ENUM)\n");
            break;
        case GL_INVALID_VALUE:
            fprintf(stderr, "(GL_INVALID_VALUE)\n");
            break;
        case GL_INVALID_OPERATION:
            fprintf(stderr, "(GL_INVALID_OPERATION)\n");
            break;
        case GL_OUT_OF_MEMORY:
            fprintf(stderr, "(GL_OUT_OF_MEMORY)\n");
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            fprintf(stderr, "(GL_INVALID_FRAMEBUFFER_OPERATION)\n");
            break;
        default:
            break;
        }

        fflush(stderr);
    }
}

int graphics_setup_window(int xpos, int ypos, int width, int height, const char *windowname , int reqdispno)
{
    EGLint configAttrs[] = {
        EGL_RED_SIZE,        1,
        EGL_GREEN_SIZE,      1,
        EGL_BLUE_SIZE,       1,
        EGL_DEPTH_SIZE,    16,
        EGL_SAMPLE_BUFFERS,  0,
        EGL_SAMPLES,         0,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };

    EGLint contextAttrs[] = {
      EGL_CONTEXT_CLIENT_VERSION, 3,
      EGL_NONE
    };

    EGLint windowAttrs[] = { EGL_NONE};
    EGLConfig* configList = NULL;
    EGLint configCount;

    int displayCount = 0;
    int dispno;

    screen_context = 0;

    screen_display_t *screenDisplayHandle = NULL;

    if (screen_create_context(&screen_context, 0))
    {
        error_exit("Error creating screen context.\n");
    }

    eglDisplay = eglGetDisplay(0);

    if (eglDisplay == EGL_NO_DISPLAY)
    {
        error_exit("EGL failed to obtain display\n");
    }

    if (!eglInitialize(eglDisplay, 0, 0))
    {
        error_exit("EGL failed to initialize\n");
    }

    if (!eglChooseConfig(eglDisplay, configAttrs, NULL, 0, &configCount) || !configCount)
    {
        error_exit("EGL failed to return any matching configurations\n");
    }

    configList = (EGLConfig*)malloc(configCount * sizeof(EGLConfig));

    if (!eglChooseConfig(eglDisplay, configAttrs, configList, configCount, &configCount) || !configCount)
    {
        error_exit("EGL failed to populate configuration list\n");
    }

    screen_window = 0;
    if (screen_create_window(&screen_window, screen_context))
    {
        error_exit("Error creating screen window.\n");
    }

    // query the total no of display avaibale from QNX CAR2 screen
    if (screen_get_context_property_iv(screen_context, SCREEN_PROPERTY_DISPLAY_COUNT, &displayCount))
    {
        error_exit("Error getting context property\n");
    }

    screenDisplayHandle = (screen_display_t *)malloc(displayCount * sizeof(screen_display_t));
    if (!screenDisplayHandle)
    {
        error_exit("Error allocating screen memory handle is getting failed\n");
    }

    // query the display handle from QNX CAR2 screen
    if (screen_get_context_property_pv(screen_context, SCREEN_PROPERTY_DISPLAYS, (void **)screenDisplayHandle))
    {
        error_exit("Error getting display handle\n");
    }

    for (dispno = 0; dispno < displayCount; dispno++)
    {
        int active = 0;
        // Query the connected status from QNX CAR2 screen
        screen_get_display_property_iv(screenDisplayHandle[dispno], SCREEN_PROPERTY_ATTACHED, &active);
        if (active)
        {
            if (reqdispno == dispno)
            {
                // Map the window buffer to user requested display port
                screen_set_window_property_pv(screen_window, SCREEN_PROPERTY_DISPLAY, (void **)&screenDisplayHandle[reqdispno]);
                break;
            }
        }
    }

    if (dispno == displayCount)
    {
        error_exit("Failed to set the requested display\n");
    }

    free(screenDisplayHandle);

    int format = SCREEN_FORMAT_RGBA8888;
    if (screen_set_window_property_iv(screen_window, SCREEN_PROPERTY_FORMAT, &format))
    {
        error_exit("Error setting SCREEN_PROPERTY_FORMAT\n");
    }

    int usage = (1 << 11); // SCREEN_USAGE_OPENGL_ES3
    if (screen_set_window_property_iv(screen_window, SCREEN_PROPERTY_USAGE, &usage))
    {
        error_exit("Error setting SCREEN_PROPERTY_USAGE\n");
    }

    EGLint interval = 1;
    if (screen_set_window_property_iv(screen_window, SCREEN_PROPERTY_SWAP_INTERVAL, &interval))
    {
        error_exit("Error setting SCREEN_PROPERTY_SWAP_INTERVAL\n");
    }

    int windowSize[2];
    windowSize[0] = width;
    windowSize[1] = height;
    if (screen_set_window_property_iv(screen_window, SCREEN_PROPERTY_SIZE, windowSize))
    {
        error_exit("Error setting SCREEN_PROPERTY_SIZE\n");
    }

    int windowOffset[2];
    windowOffset[0] = xpos;
    windowOffset[1] = ypos;
    if (screen_set_window_property_iv(screen_window, SCREEN_PROPERTY_POSITION, windowOffset))
    {
        error_exit("Error setting SCREEN_PROPERTY_POSITION\n");
    }

    if (screen_create_window_buffers(screen_window, 2))
    {
        error_exit("Error creating two window buffers.\n");
    }

    eglSurface = eglCreateWindowSurface(eglDisplay, configList[0], (EGLNativeWindowType)screen_window, windowAttrs);
    if (!eglSurface)
    {
        error_exit("EGL couldn't create window\n");
    }

    eglBindAPI(EGL_OPENGL_ES_API);

    eglContext = eglCreateContext(eglDisplay, configList[0], NULL, contextAttrs);
    if (!eglContext)
    {
        error_exit("EGL couldn't create context\n");
    }
    
    if (!eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext))
    {
        error_exit("EGL couldn't make context/surface current\n");
    }

    EGLint Context_RendererType;
    eglQueryContext(eglDisplay, eglContext,EGL_CONTEXT_CLIENT_TYPE, &Context_RendererType);

    switch (Context_RendererType)
    {
    case EGL_OPENGL_API:
        printf("Using OpenGL API\n");
        break;
    case EGL_OPENGL_ES_API:
        printf("Using OpenGL ES API");
        break;
    case EGL_OPENVG_API:
        error_exit("Context Query Returned OpenVG. This is Unsupported\n");
    default:
        error_exit("Unknown Context Type. %04X\n", Context_RendererType);
    }

    return 1;
}

void graphics_set_windowtitle(const char *windowname)
{
    // Do nothing on screen
}

void graphics_swap_buffers()
{
    eglSwapBuffers(eglDisplay, eglSurface);
}

void graphics_close_window()
{
    if (eglDisplay != EGL_NO_DISPLAY) 
    {
        eglMakeCurrent(eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

        if (eglContext != EGL_NO_CONTEXT)
        {
            eglDestroyContext(eglDisplay, eglContext);
        }
      
        if (eglSurface != EGL_NO_SURFACE)
        {
            eglDestroySurface(eglDisplay, eglSurface);
        }
      
        eglTerminate(eglDisplay);
    }

    if (screen_window)
    {
        screen_destroy_window(screen_window);
        screen_window = NULL;
    }

    if (screen_context)
    {
        screen_destroy_context(screen_context);
    }
}
