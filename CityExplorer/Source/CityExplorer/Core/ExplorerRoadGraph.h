#pragma once
#include "CoreMinimal.h"
struct FExplorerRoad;
struct FExplorerRoadHit;
// Metric, directed routing independent of rendering, input and widgets.
class FExplorerRoadGraph
{
public:
    void Build(const TArray<FExplorerRoad>& Roads);
    TArray<FVector2D> Route(const TArray<FExplorerRoad>& Roads, const FExplorerRoadHit& Start, const FExplorerRoadHit& Finish) const;
private:
    struct FEdge { int32 Target; double Cost; };
    TMap<FString, int32> Ids;
    TArray<FVector2D> Points;
    TArray<TArray<FEdge>> Edges;
    TArray<int32> FindPath(int32 From, int32 To) const;
};
