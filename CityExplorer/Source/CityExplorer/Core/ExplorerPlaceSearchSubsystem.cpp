#include "ExplorerPlaceSearchSubsystem.h"
#include "HttpModule.h"
#include "Interfaces/IHttpResponse.h"
#include "Engine/GameInstance.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonWriter.h"
namespace
{
    TSharedPtr<FJsonObject> ResponseJson(FHttpResponsePtr Response)
    {
        TSharedPtr<FJsonObject> Data;
        if (Response && Response->GetResponseCode() >= 200 && Response->GetResponseCode() < 300)
            FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Response->GetContentAsString()), Data);
        return Data;
    }
}
void UExplorerPlaceSearchSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection); ApiKey = FPlatformMisc::GetEnvironmentVariable(TEXT("CITY_EXPLORER_GOOGLE_PLACES_API_KEY")).TrimStartAndEnd();
}
void UExplorerPlaceSearchSubsystem::Cancel() { ++Generation; if (Request) { Request->OnProcessRequestComplete().Unbind(); Request->CancelRequest(); Request.Reset(); } }
void UExplorerPlaceSearchSubsystem::Deinitialize() { Cancel(); ApiKey.Reset(); Super::Deinitialize(); }
void UExplorerPlaceSearchSubsystem::Search(const FString& Query)
{
    Cancel(); const FString Clean = Query.TrimStartAndEnd(); const int32 Token = Generation;
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (Clean.Len() < 2) { OnResults.Broadcast({}); return; }
    if (!HasGoogleKey()) { OnResults.Broadcast(Map->SearchOffline(Clean)); return; }
    auto Body = MakeShared<FJsonObject>(); Body->SetStringField(TEXT("input"), Clean); Body->SetStringField(TEXT("languageCode"), TEXT("en")); Body->SetStringField(TEXT("regionCode"), TEXT("es"));
    auto Low = MakeShared<FJsonObject>(); Low->SetNumberField(TEXT("latitude"), 41.3170354); Low->SetNumberField(TEXT("longitude"), 2.0524977);
    auto High = MakeShared<FJsonObject>(); High->SetNumberField(TEXT("latitude"), 41.4679135); High->SetNumberField(TEXT("longitude"), 2.2283555);
    auto Rectangle = MakeShared<FJsonObject>(); Rectangle->SetObjectField(TEXT("low"), Low); Rectangle->SetObjectField(TEXT("high"), High);
    auto Restriction = MakeShared<FJsonObject>(); Restriction->SetObjectField(TEXT("rectangle"), Rectangle); Body->SetObjectField(TEXT("locationRestriction"), Restriction);
    FString Payload; FJsonSerializer::Serialize(Body, TJsonWriterFactory<>::Create(&Payload));
    Request = FHttpModule::Get().CreateRequest(); Request->SetURL(TEXT("https://places.googleapis.com/v1/places:autocomplete")); Request->SetVerb(TEXT("POST"));
    Request->SetTimeout(8); Request->SetHeader(TEXT("Content-Type"), TEXT("application/json")); Request->SetHeader(TEXT("X-Goog-Api-Key"), ApiKey);
    Request->SetHeader(TEXT("X-Goog-FieldMask"), TEXT("suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat")); Request->SetContentAsString(Payload);
    Request->OnProcessRequestComplete().BindWeakLambda(this, [this, Token, Clean](FHttpRequestPtr Sent, FHttpResponsePtr Response, bool Success)
    {
        if (Token != Generation) return; auto Data = Success ? ResponseJson(Response) : nullptr;
        if (!Data) { OnResults.Broadcast(GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>()->SearchOffline(Clean)); return; }
        TArray<FExplorerPlace> Results; const TArray<TSharedPtr<FJsonValue>>* Suggestions = nullptr;
        if (Data->TryGetArrayField(TEXT("suggestions"), Suggestions)) for (const auto& Value : *Suggestions)
        {
            const TSharedPtr<FJsonObject>* Prediction = nullptr;
            if (!Value->AsObject()->TryGetObjectField(TEXT("placePrediction"), Prediction)) continue;
            FExplorerPlace P; if (!(*Prediction)->TryGetStringField(TEXT("placeId"), P.Id)) continue;
            const TSharedPtr<FJsonObject>* Text = nullptr;
            if ((*Prediction)->TryGetObjectField(TEXT("text"), Text)) (*Text)->TryGetStringField(TEXT("text"), P.Name);
            P.Source = TEXT("google"); Results.Add(P);
        }
        OnResults.Broadcast(Results);
    });
    if (!Request->ProcessRequest()) OnResults.Broadcast(Map->SearchOffline(Clean));
}
void UExplorerPlaceSearchSubsystem::Resolve(FExplorerPlace Place)
{
    Cancel(); if (Place.Source != TEXT("google")) { OnResolved.Broadcast(Place); return; }
    if (ApiKey.IsEmpty() || Place.Id.IsEmpty() || Place.Id.Contains(TEXT("/"))) { OnError.Broadcast(TEXT("Unable to resolve selected place")); return; }
    const int32 Token = Generation;
    Request = FHttpModule::Get().CreateRequest(); Request->SetVerb(TEXT("GET")); Request->SetTimeout(8);
    Request->SetURL(TEXT("https://places.googleapis.com/v1/places/") + Place.Id); Request->SetHeader(TEXT("X-Goog-Api-Key"), ApiKey);
    Request->SetHeader(TEXT("X-Goog-FieldMask"), TEXT("id,displayName,formattedAddress,location"));
    Request->OnProcessRequestComplete().BindWeakLambda(this, [this, Token, Place](FHttpRequestPtr Sent, FHttpResponsePtr Response, bool Success) mutable
    {
        if (Token != Generation) return; auto Data = Success ? ResponseJson(Response) : nullptr;
        const TSharedPtr<FJsonObject>* Location = nullptr; double Lat = 0, Lon = 0;
        if (!Data || !Data->TryGetObjectField(TEXT("location"), Location) || !(*Location)->TryGetNumberField(TEXT("latitude"), Lat) || !(*Location)->TryGetNumberField(TEXT("longitude"), Lon) || !FMath::IsFinite(Lat) || !FMath::IsFinite(Lon))
        { OnError.Broadcast(TEXT("Unable to resolve selected place")); return; }
        Place.Point = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>()->ProjectLonLat(Lon, Lat);
        Data->TryGetStringField(TEXT("formattedAddress"), Place.Address); OnResolved.Broadcast(Place);
    });
    if (!Request->ProcessRequest()) OnError.Broadcast(TEXT("Unable to resolve selected place"));
}
