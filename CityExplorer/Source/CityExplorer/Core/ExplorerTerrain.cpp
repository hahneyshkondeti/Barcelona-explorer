#include "ExplorerTerrain.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
bool FExplorerTerrain::Load(const FString& DataRoot, FString& Error)
{
    Samples.Reset(); Columns = Rows = 0;
    FString Text; TSharedPtr<FJsonObject> Meta;
    if (!FFileHelper::LoadFileToString(Text, *FPaths::Combine(DataRoot, TEXT("terrain/metadata.json"))) ||
        !FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Text), Meta) || !Meta.IsValid())
    { Error = TEXT("Unable to read terrain metadata"); return false; }
    double C = 0, R = 0, S = 0;
    const TArray<TSharedPtr<FJsonValue>>* O = nullptr;
    if (!Meta->TryGetNumberField(TEXT("columns"), C) || !Meta->TryGetNumberField(TEXT("rows"), R) ||
        !Meta->TryGetNumberField(TEXT("spacing_m"), S) || !Meta->TryGetArrayField(TEXT("origin"), O) || O->Num() != 2 ||
        C < 2 || R < 2 || C > 100000 || R > 100000 || S <= 0 || C * R > MAX_int32)
    { Error = TEXT("Invalid terrain dimensions"); return false; }
    TArray<uint8> Bytes;
    if (!FFileHelper::LoadFileToArray(Bytes, *FPaths::Combine(DataRoot, TEXT("terrain/heights.f32"))) || int64(Bytes.Num()) != int64(C) * int64(R) * 4)
    { Error = TEXT("Terrain sample size does not match metadata"); return false; }
    Columns = int32(C); Rows = int32(R); Spacing = S;
    Origin = FVector2D((*O)[0]->AsNumber(), (*O)[1]->AsNumber());
    Samples.SetNumUninitialized(Columns * Rows);
    // Mac arm64 is little endian; file format explicitly specifies little-endian float32.
    FMemory::Memcpy(Samples.GetData(), Bytes.GetData(), Bytes.Num());
    for (float V : Samples) if (!FMath::IsFinite(V))
    { Samples.Reset(); Error = TEXT("Terrain contains non-finite samples"); return false; }
    return true;
}
double FExplorerTerrain::Height(double EastMetres, double SouthMetres) const
{
    if (!IsValid() || !FMath::IsFinite(EastMetres) || !FMath::IsFinite(SouthMetres)) return 0;
    const double X = (EastMetres - Origin.X) / Spacing, Y = (SouthMetres - Origin.Y) / Spacing;
    const int32 I = FMath::Clamp(FMath::FloorToInt(X), 0, Columns - 2), J = FMath::Clamp(FMath::FloorToInt(Y), 0, Rows - 2);
    const double U = FMath::Clamp(X - I, 0.0, 1.0), V = FMath::Clamp(Y - J, 0.0, 1.0);
    const double A = Samples[J * Columns + I], B = Samples[J * Columns + I + 1];
    const double C = Samples[(J + 1) * Columns + I], D = Samples[(J + 1) * Columns + I + 1];
    return U >= V ? A + U * (B - A) + V * (D - B) : A + V * (C - A) + U * (D - C);
}
