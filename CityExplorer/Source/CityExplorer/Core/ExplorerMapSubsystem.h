#pragma once
#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "ExplorerTerrain.h"
#include "ExplorerRoadGraph.h"
#include "ExplorerMapSubsystem.generated.h"

USTRUCT(BlueprintType)
struct FExplorerPlace
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) FString Id;
    UPROPERTY(BlueprintReadOnly) FString Name;
    UPROPERTY(BlueprintReadOnly) FString Address;
    UPROPERTY(BlueprintReadOnly) FString Source = TEXT("offline");
    UPROPERTY(BlueprintReadOnly) FVector2D Point = FVector2D::ZeroVector;
};
struct FExplorerRoad
{
    FString Id, Name, AId, BId;
    FVector2D A, B;
    double Width = 0;
    int32 OneWay = 0;
};
struct FExplorerRoadHit
{
    int32 Road = INDEX_NONE;
    FVector2D Point = FVector2D::ZeroVector;
    double Distance = TNumericLimits<double>::Max();
};

class FJsonObject;

// Immutable geographic data outlives levels. Rendering and active tile ownership live in the world.
UCLASS()
class CITYEXPLORER_API UExplorerMapSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintCallable) bool LoadCity();
    UFUNCTION(BlueprintPure) bool IsReady() const { return bReady; }
    UFUNCTION(BlueprintPure) FString GetLastError() const { return LastError; }
    UFUNCTION(BlueprintCallable) TArray<FExplorerPlace> SearchOffline(const FString& Query, int32 Limit = 20);
    UFUNCTION(BlueprintCallable) bool SafeSpawn(FVector2D Point, FVector& OutPosition, FRotator& OutRotation) const;
    TArray<FVector2D> Route(FVector2D From, FVector2D To) const { return Graph.Route(Roads, NearestRoad(From), NearestRoad(To)); }
    FExplorerRoadHit NearestRoad(FVector2D Point) const;
    TSet<FIntPoint> RequiredTiles(FVector2D Point, int32 Radius = 2) const;
    TSharedPtr<FJsonObject> LoadTile(FIntPoint Cell) const;
    const FExplorerTerrain& GetTerrain() const { return Terrain; }
    const TArray<FExplorerRoad>& GetRoads() const { return Roads; }
    FVector2D GetStart() const { return Start; }
    FVector2D GetOriginLonLat() const { return OriginLonLat; }
    FVector2D ProjectLonLat(double Longitude, double Latitude) const;
    static FString Normalize(const FString& Value);
    static bool NumberMatches(const FString& Query, const FString& Number);
    static FVector ToUnreal(FVector2D Point, double Elevation) { return FVector(Point.X * 100, Point.Y * 100, Elevation * 100); }
private:
    bool bReady = false;
    FString LastError, DataRoot;
    FExplorerTerrain Terrain;
    FExplorerRoadGraph Graph;
    FVector2D Start, OriginLonLat, BoundsMin, BoundsMax;
    TArray<FExplorerRoad> Roads;
    TArray<FExplorerPlace> Places;
    TMap<FIntPoint, TArray<int32>> RoadCells;
    TMap<FIntPoint, TArray<FIntPoint>> Dependencies;
    TMap<FIntPoint, FString> Tiles;
    TSharedPtr<FJsonObject> AddressIndex;
};
