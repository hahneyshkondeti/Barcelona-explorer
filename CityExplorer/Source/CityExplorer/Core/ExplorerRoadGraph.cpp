#include "ExplorerRoadGraph.h"
#include "ExplorerMapSubsystem.h"
#include <queue>
void FExplorerRoadGraph::Build(const TArray<FExplorerRoad>& Roads)
{
    Ids.Reset(); Points.Reset(); Edges.Reset();
    auto Node = [&](const FString& Id, FVector2D P)
    {
        if (const int32* Existing = Ids.Find(Id)) return *Existing;
        const int32 I = Points.Add(P); Ids.Add(Id, I); Edges.AddDefaulted(); return I;
    };
    for (const auto& R : Roads)
    {
        const int32 A = Node(R.AId, R.A), B = Node(R.BId, R.B); const double Cost = (R.B - R.A).Size();
        if (R.OneWay != -1) Edges[A].Add({B, Cost});
        if (R.OneWay != 1) Edges[B].Add({A, Cost});
    }
}
TArray<int32> FExplorerRoadGraph::FindPath(int32 From, int32 To) const
{
    struct FOpen { int32 Node; double Score, Cost; bool operator<(const FOpen& Other) const { return Score > Other.Score; } };
    std::priority_queue<FOpen> Open; TArray<double> Costs; Costs.Init(TNumericLimits<double>::Max(), Points.Num());
    TArray<int32> Parent; Parent.Init(INDEX_NONE, Points.Num());
    Costs[From] = 0; Open.push({From, (Points[From] - Points[To]).Size(), 0});
    while (!Open.empty())
    {
        const FOpen Current = Open.top(); Open.pop(); if (Current.Cost > Costs[Current.Node]) continue;
        if (Current.Node == To)
        {
            TArray<int32> Result; for (int32 N = To; N != INDEX_NONE; N = Parent[N]) Result.Add(N);
            Algo::Reverse(Result); return Result;
        }
        for (const auto& Edge : Edges[Current.Node])
        {
            const double Candidate = Current.Cost + Edge.Cost; if (Candidate >= Costs[Edge.Target]) continue;
            Costs[Edge.Target] = Candidate; Parent[Edge.Target] = Current.Node;
            Open.push({Edge.Target, Candidate + (Points[Edge.Target] - Points[To]).Size(), Candidate});
        }
    }
    return {};
}
TArray<FVector2D> FExplorerRoadGraph::Route(const TArray<FExplorerRoad>& Roads, const FExplorerRoadHit& Start, const FExplorerRoadHit& Finish) const
{
    if (!Roads.IsValidIndex(Start.Road) || !Roads.IsValidIndex(Finish.Road)) return {};
    const auto& S = Roads[Start.Road]; const auto& F = Roads[Finish.Road];
    double BestCost = TNumericLimits<double>::Max(); TArray<FVector2D> Best;
    const double Progress = FVector2D::DotProduct(Finish.Point - Start.Point, S.B - S.A);
    if (Start.Road == Finish.Road && (S.OneWay == 0 || (S.OneWay == 1 && Progress >= 0) || (S.OneWay == -1 && Progress <= 0)))
    { Best = {Start.Point, Finish.Point}; BestCost = (Finish.Point - Start.Point).Size(); }
    TArray<FString> Starts, Ends;
    if (S.OneWay != 1) Starts.Add(S.AId); if (S.OneWay != -1) Starts.Add(S.BId);
    if (F.OneWay != -1) Ends.Add(F.AId); if (F.OneWay != 1) Ends.Add(F.BId);
    for (const auto& A : Starts) for (const auto& B : Ends)
    {
        const int32* From = Ids.Find(A); const int32* To = Ids.Find(B); if (!From || !To) continue;
        const auto Path = FindPath(*From, *To); if (Path.IsEmpty()) continue;
        double Cost = (Start.Point - Points[Path[0]]).Size() + (Finish.Point - Points[Path.Last()]).Size();
        for (int32 I = 1; I < Path.Num(); ++I) Cost += (Points[Path[I]] - Points[Path[I - 1]]).Size();
        if (Cost >= BestCost) continue; BestCost = Cost; Best = {Start.Point};
        for (int32 N : Path) Best.Add(Points[N]); Best.Add(Finish.Point);
    }
    TArray<FVector2D> Result;
    for (auto P : Best) if (Result.IsEmpty() || (P - Result.Last()).Size() > 0.1) Result.Add(P);
    return Result;
}
