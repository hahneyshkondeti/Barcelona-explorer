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
