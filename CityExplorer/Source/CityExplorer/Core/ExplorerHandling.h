#pragma once
#include "CoreMinimal.h"

// Simulation uses metres/seconds; the Pawn adapter converts to Unreal centimetres.
struct FExplorerHandling
{
    double Speed = 0, ThrottleBlend = 0, ReverseHold = 0;
    double Steering = 0, SteeringAngle = 0, YawRate = 0;
    static constexpr double MaxSpeed = 150.0 / 3.6;
    static constexpr double ReverseSpeed = 5.0;
    void Reset() { *this = FExplorerHandling(); }
    void Step(double Delta, double Gas, double Brake, double Steer);
};
