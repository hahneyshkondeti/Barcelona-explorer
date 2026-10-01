#include "ExplorerVehicleAssetTools.h"
#include "PhysicsEngine/PhysicsAsset.h"
#include "PhysicsEngine/SkeletalBodySetup.h"
bool UExplorerVehicleAssetTools::ConfigureChassis(UPhysicsAsset* Asset)
{
#if WITH_EDITOR
    if (!Asset) return false;
    USkeletalBodySetup* Root = nullptr;
    for (const auto& Body : Asset->SkeletalBodySetups) if (Body && Body->BoneName == TEXT("Root")) Root = Body;
    if (!Root) return false;
    Asset->Modify(); Root->Modify();
    Root->AggGeom.EmptyElements();
    FKBoxElem Box(370, 185, 100); Box.Center = FVector(0, 0, 65);
    Root->AggGeom.BoxElems.Add(Box);
    Root->InvalidatePhysicsData(); Root->CreatePhysicsMeshes();
    Asset->SkeletalBodySetups.Reset(); Asset->SkeletalBodySetups.Add(Root);
    Asset->ConstraintSetup.Reset(); Asset->UpdateBodySetupIndexMap(); Asset->UpdateBoundsBodiesArray();
    Asset->RefreshPhysicsAssetChange(); Asset->MarkPackageDirty();
    return true;
#else
    return false;
#endif
}

#if WITH_EDITOR
#include "Animation/AnimBlueprint.h"
#include "Animation/AnimBlueprintGeneratedClass.h"
#include "VehicleAnimationInstance.h"
#include "Kismet2/KismetEditorUtilities.h"
#include "AnimGraphNode_Root.h"
#include "AnimGraphNode_LocalRefPose.h"
#include "AnimGraphNode_LocalToComponentSpace.h"
#include "AnimGraphNode_ComponentToLocalSpace.h"
#include "AnimGraphNode_WheelController.h"
#include "EdGraph/EdGraph.h"
#include "EdGraph/EdGraphSchema.h"
#include "UObject/Package.h"
#endif
UBlueprint* UExplorerVehicleAssetTools::CreateWheelAnimation(USkeleton* Skeleton)
{
#if WITH_EDITOR
    if (!Skeleton) return nullptr;
    auto* Package = CreatePackage(TEXT("/Game/CityExplorer/Vehicles/ABP_TouringCar"));
    auto* BP = Cast<UAnimBlueprint>(FKismetEditorUtilities::CreateBlueprint(UVehicleAnimationInstance::StaticClass(), Package, TEXT("ABP_TouringCar"), BPTYPE_Normal, UAnimBlueprint::StaticClass(), UAnimBlueprintGeneratedClass::StaticClass()));
    BP->TargetSkeleton = Skeleton;
    UEdGraph* Graph = nullptr;
    for (const auto& G : BP->FunctionGraphs) if (G->GetFName() == TEXT("AnimGraph")) Graph = G;
    if (!Graph) return nullptr;
    UAnimGraphNode_Root* Root = nullptr;
    for (const auto& N : Graph->Nodes) if (auto* R = Cast<UAnimGraphNode_Root>(N)) Root = R;
    if (!Root) return nullptr;
    auto Add = [Graph](UClass* Class) { auto* N = NewObject<UEdGraphNode>(Graph, Class); Graph->AddNode(N); N->CreateNewGuid(); N->PostPlacedNewNode(); N->AllocateDefaultPins(); return N; };
    UEdGraphNode* Nodes[] = {Add(UAnimGraphNode_LocalRefPose::StaticClass()), Add(UAnimGraphNode_LocalToComponentSpace::StaticClass()), Add(UAnimGraphNode_WheelController::StaticClass()), Add(UAnimGraphNode_ComponentToLocalSpace::StaticClass()), Root};
    for (int32 I=0; I<4; ++I) {
        UEdGraphPin* Out=nullptr; UEdGraphPin* In=nullptr;
        for (auto* P : Nodes[I]->Pins) if (P->Direction == EGPD_Output) Out=P;
        for (auto* P : Nodes[I+1]->Pins) if (P->Direction == EGPD_Input && P->PinType.PinCategory == TEXT("struct")) { In=P; break; }
        if (!Out || !In || !Graph->GetSchema()->TryCreateConnection(Out,In)) return nullptr;
        Nodes[I]->NodePosX = -600+I*150;
    }
    FKismetEditorUtilities::CompileBlueprint(BP); BP->MarkPackageDirty(); return BP;
#else
    return nullptr;
#endif
}
