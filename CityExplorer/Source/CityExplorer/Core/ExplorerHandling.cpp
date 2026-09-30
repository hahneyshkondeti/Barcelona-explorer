#include "ExplorerHandling.h"
namespace
{
    double Approach(double Current, double Target, double Amount)
    {
        return Current < Target ? FMath::Min(Current + Amount, Target) : FMath::Max(Current - Amount, Target);
    }
}
void FExplorerHandling::Step(double Delta, double Gas, double Brake, double Steer)
{
    if (!FMath::IsFinite(Delta) || Delta <= 0) return;
    Gas = FMath::Clamp(Gas, 0.0, 1.0);
    Brake = FMath::Clamp(Brake, 0.0, 1.0);
    ThrottleBlend = Approach(ThrottleBlend, Brake == 0 ? Gas : 0.0, Delta * 4);
    if (Brake > 0)
    {
        if (Speed > 0 || Gas > 0)
        {
            Speed = Approach(Speed, 0, 18 * Brake * Delta);
            ReverseHold = 0;
        }
        else
        {
            ReverseHold += Delta;
            if (ReverseHold >= 0.35) Speed = Approach(Speed, -ReverseSpeed * Brake, 4 * Brake * Delta);
        }
    }
    else if (Gas > 0)
    {
        ReverseHold = 0;
        if (Speed < 0) Speed = Approach(Speed, 0, 14 * Gas * Delta);
        else Speed = Approach(Speed, MaxSpeed * Gas, 9.5 * (1 - 0.55 * Speed / MaxSpeed) * ThrottleBlend * Delta);
    }
    else
    {
        ReverseHold = 0;
        Speed = Approach(Speed, 0, (1 + FMath::Abs(Speed) * 0.08) * Delta);
    }
    const double Target = FMath::Clamp(Steer, -1.0, 1.0);
    Steering = Approach(Steering, Target, (FMath::IsNearlyZero(Target) ? 5.5 : 3.5) * Delta);
    SteeringAngle = Steering * FMath::Lerp(0.48, 0.16, FMath::Clamp(FMath::Abs(Speed) / 23.0, 0.0, 1.0));
    const double Limit = FMath::Min(0.9, 6.5 / FMath::Max(FMath::Abs(Speed), 1.0));
    const double Requested = FMath::Clamp(Speed / 2.55 * FMath::Tan(SteeringAngle), -Limit, Limit);
    YawRate = FMath::Lerp(YawRate, Requested, 1 - FMath::Exp(-10 * Delta));
    if (FMath::Abs(Speed) < 0.05) YawRate = 0;
}
