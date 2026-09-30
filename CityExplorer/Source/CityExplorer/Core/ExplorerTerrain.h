#pragma once
#include "CoreMinimal.h"

struct FExplorerTerrain
{
    FVector2D Origin = FVector2D::ZeroVector;
    int32 Columns = 0, Rows = 0;
    double Spacing = 6;
    TArray<float> Samples;
    bool Load(const FString& DataRoot, FString& Error);
    bool IsValid() const { return Columns >= 2 && Rows >= 2 && Spacing > 0 && Samples.Num() == int64(Columns) * Rows; }
    double Height(double EastMetres, double SouthMetres) const;
};
