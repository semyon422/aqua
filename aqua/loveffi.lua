-- https://love2d.org/wiki/Conversion_between_love_objects_and_FFI_structures

local ffi = require("ffi")

ffi.cdef [[
    typedef enum  {
        INVALID_ID = 0,
        OBJECT_ID,
        DATA_ID,
        MODULE_ID,
        STREAM_ID,

        // Filesystem.
        FILESYSTEM_FILE_ID,
        FILESYSTEM_DROPPED_FILE_ID,
        FILESYSTEM_FILE_DATA_ID,

        // Font
        FONT_GLYPH_DATA_ID,
        FONT_RASTERIZER_ID,

        // Graphics
        GRAPHICS_DRAWABLE_ID,
        GRAPHICS_TEXTURE_ID,
        GRAPHICS_IMAGE_ID,
        GRAPHICS_QUAD_ID,
        GRAPHICS_FONT_ID,
        GRAPHICS_PARTICLE_SYSTEM_ID,
        GRAPHICS_SPRITE_BATCH_ID,
        GRAPHICS_CANVAS_ID,
        GRAPHICS_SHADER_ID,
        GRAPHICS_MESH_ID,
        GRAPHICS_TEXT_ID,
        GRAPHICS_VIDEO_ID,

        // Image
        IMAGE_IMAGE_DATA_ID,
        IMAGE_COMPRESSED_IMAGE_DATA_ID,

        // Joystick
        JOYSTICK_JOYSTICK_ID,

        // Math
        MATH_RANDOM_GENERATOR_ID,
        MATH_BEZIER_CURVE_ID,
        MATH_COMPRESSED_DATA_ID,

        // Audio
        AUDIO_SOURCE_ID,

        // Sound
        SOUND_SOUND_DATA_ID,
        SOUND_DECODER_ID,

        // Mouse
        MOUSE_CURSOR_ID,

        // Physics
        PHYSICS_WORLD_ID,
        PHYSICS_CONTACT_ID,
        PHYSICS_BODY_ID,
        PHYSICS_FIXTURE_ID,
        PHYSICS_SHAPE_ID,
        PHYSICS_CIRCLE_SHAPE_ID,
        PHYSICS_POLYGON_SHAPE_ID,
        PHYSICS_EDGE_SHAPE_ID,
        PHYSICS_CHAIN_SHAPE_ID,
        PHYSICS_JOINT_ID,
        PHYSICS_MOUSE_JOINT_ID,
        PHYSICS_DISTANCE_JOINT_ID,
        PHYSICS_PRISMATIC_JOINT_ID,
        PHYSICS_REVOLUTE_JOINT_ID,
        PHYSICS_PULLEY_JOINT_ID,
        PHYSICS_GEAR_JOINT_ID,
        PHYSICS_FRICTION_JOINT_ID,
        PHYSICS_WELD_JOINT_ID,
        PHYSICS_ROPE_JOINT_ID,
        PHYSICS_WHEEL_JOINT_ID,
        PHYSICS_MOTOR_JOINT_ID,

        // Thread
        THREAD_THREAD_ID,
        THREAD_CHANNEL_ID,

        // Video
        VIDEO_VIDEO_STREAM_ID,

        // The modules themselves. Only add abstracted modules here.
        MODULE_FILESYSTEM_ID,
        MODULE_GRAPHICS_ID,
        MODULE_IMAGE_ID,
        MODULE_SOUND_ID,

        // Count the number of bits needed.
        TYPE_MAX_ENUM
    } Type;

    typedef struct Object {
    } Object;

    typedef struct Proxy {
        Type type;
        Object * object;
    };
]]

local conv = {}

function conv.objectToPointer(Object)
    local Proxy = ffi.cast("Proxy *", Object)
    return Proxy.object, tonumber(Proxy.type), Object:type()
end

function conv.pointerToObject(CData, Type, TypeName)
    local Object = newproxy(true)
    local Metatable = debug.getregistry()[TypeName]
    debug.setmetatable(Object, Metatable)

    local Proxy = ffi.cast("Proxy *", Object)
    Proxy.type = Type
    Proxy.object = CData

    return Object
end

return conv
