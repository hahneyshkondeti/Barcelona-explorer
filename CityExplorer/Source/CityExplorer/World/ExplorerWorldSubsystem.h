#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Subsystems/WorldSubsystem.h"
#include "ExplorerWorldSubsystem.generated.h"
class UProceduralMeshComponent;
class UExplorerMapSubsystem;
class UMaterialInterface;
UCLASS()
class CITYEXPLORER_API AExplorerTile : public AActor
{
    GENERATED_BODY()
public:
    AExplorerTile();
    void Build(FIntPoint Cell, UExplorerMapSubsystem& Map, UMaterialInterface* Material);
    UPROPERTY() TObjectPtr<UProceduralMeshComponent> Mesh;
};
UCLASS()
class CITYEXPLORER_API UExplorerWorldSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()
public:
    virtual void Tick(float Delta) override;
    virtual TStatId GetStatId() const override { RETURN_QUICK_DECLARE_CYCLE_STAT(UExplorerWorldSubsystem, STATGROUP_Tickables); }
    virtual bool DoesSupportWorldType(EWorldType::Type Type) const override;
    void StreamAt(FVector Position, bool Immediate);
private:
    UPROPERTY() TMap<FIntPoint, TObjectPtr<AExplorerTile>> Active;
    UPROPERTY() TObjectPtr<UMaterialInterface> Material;
    TSet<FIntPoint> Desired;
    TArray<FIntPoint> Pending;
    FIntPoint LastCell = FIntPoint(MAX_int32, MAX_int32);
    void LoadOne(FIntPoint Cell);
};
