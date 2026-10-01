#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ExplorerPhysicsProbe.generated.h"
// Opt-in development smoke test. Uses the real map, chassis, suspension and Chaos simulation.
UCLASS(NotBlueprintable, Transient)
class AExplorerPhysicsProbe : public AActor
{
    GENERATED_BODY()
public:
    AExplorerPhysicsProbe();
    virtual void BeginPlay() override;
    virtual void Tick(float Delta) override;
private:
    UPROPERTY() TObjectPtr<class AExplorerVehicle> Car;
    UPROPERTY() TObjectPtr<class AExplorerPlayerController> Controller;
    double StageStart = 0;
    int32 Stage = 0;
    FVector Start, PausePosition;
    void Fail(const TCHAR* Reason);
};
