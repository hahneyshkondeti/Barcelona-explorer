#include "ExplorerVehicleAnimation.h"
#include "AnimNode_WheelController.h"
#include "AnimNodes/AnimNode_RefPose.h"
#include "Animation/AnimNode_Root.h"
#include "Animation/AnimNodeSpaceConversions.h"
#include "ChaosWheeledVehicleMovementComponent.h"
#include "GameFramework/Actor.h"
namespace
{
    struct FExplorerVehicleProxy : FVehicleAnimationInstanceProxy
    {
        FAnimNode_RefPose Reference;
        FAnimNode_ConvertLocalToComponentSpace ToComponent;
        FAnimNode_WheelController Wheels;
        FAnimNode_ConvertComponentToLocalSpace ToLocal;
        FAnimNode_Root Root;
        explicit FExplorerVehicleProxy(UAnimInstance* Instance) : FVehicleAnimationInstanceProxy(Instance) {}
        virtual void Initialize(UAnimInstance* Instance) override
        {
            FVehicleAnimationInstanceProxy::Initialize(Instance);
            if (AActor* Owner = Instance->GetOwningActor())
                if (auto* Movement = Owner->FindComponentByClass<UChaosWheeledVehicleMovementComponent>()) SetWheeledVehicleComponent(Movement);
            ToComponent.LocalPose.SetLinkNode(&Reference); Wheels.ComponentPose.SetLinkNode(&ToComponent);
            ToLocal.ComponentPose.SetLinkNode(&Wheels); Root.Result.SetLinkNode(&ToLocal);
            Root.Initialize_AnyThread(FAnimationInitializeContext(this));
        }
        virtual void CacheBones() override { Root.CacheBones_AnyThread(FAnimationCacheBonesContext(this)); }
        virtual void UpdateAnimationNode(const FAnimationUpdateContext& Context) override { Root.Update_AnyThread(Context); }
        virtual bool Evaluate(FPoseContext& Output) override { Root.Evaluate_AnyThread(Output); return true; }
    };
}
FAnimInstanceProxy* UExplorerVehicleAnimation::CreateAnimInstanceProxy() { return new FExplorerVehicleProxy(this); }
void UExplorerVehicleAnimation::DestroyAnimInstanceProxy(FAnimInstanceProxy* Proxy) { delete Proxy; }
