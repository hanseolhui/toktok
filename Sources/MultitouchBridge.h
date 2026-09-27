// MultitouchSupport.framework (macOS 비공개 프레임워크) 의 터치 데이터 구조.
// 함수는 링크하지 않고 main.swift 에서 dlsym 으로 불러옵니다.
#include <stdbool.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier;     // 손가락이 닿아 있는 동안 유지되는 ID
    int state;          // 3: 닿기 시작, 4: 닿아 있음, 5: 떨어지는 중 …
    int fingerID;
    int handID;
    MTReadout normalized; // 0~1 좌표 (왼쪽 아래가 0,0)
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
