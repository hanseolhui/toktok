// Touch data layout of MultitouchSupport.framework (private macOS framework).
// Functions are not linked; they are loaded at runtime with dlsym (see Multitouch.swift).
#include <stdbool.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier;     // stays the same while the finger is down
    int state;          // 3: touching begins, 4: touching, 5: lifting …
    int fingerID;
    int handID;
    MTReadout normalized; // 0…1, origin at the bottom-left
    float size;
    int zero1;
    float angle, majorAxis, minorAxis;
    MTReadout mm;
    int zero2[2];
    float unk2;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(MTDeviceRef device, MTTouch *touches, int count,
                                         double timestamp, int frame);
