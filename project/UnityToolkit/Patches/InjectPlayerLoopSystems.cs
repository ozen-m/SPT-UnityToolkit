using CustomPlayerLoopSystem;
using HarmonyLib;
using JetBrains.Annotations;
using SPT.Reflection.Patching;
using System.Reflection;
using UnityEngine.LowLevel;
#if DEBUG
using BepInEx.Logging;
using VContainer;
using VContainer.Unity;
#endif

namespace UnityToolkit.Patches;

#pragma warning disable CS1591 // Missing XML comment for publicly visible type or member

/// <summary>
/// This patch is required to inject UniTask and VContainer's PlayerLoopSystems after EFT has injected its custom PlayerLoopSystems.
/// </summary>
[UsedImplicitly]
public class InjectPlayerLoopSystems : ModulePatch
{
	protected override MethodBase GetTargetMethod()
	{
		return AccessTools.Method(typeof(CustomPlayerLoopSystemsInjector),
			"Injection");
	}

	[PatchPrefix]
	private static void PatchPrefix()
	{
		InjectUniTaskPlayerLoopSystems();
#if DEBUG
		TestVContainer();
#endif
	}

	private static void InjectUniTaskPlayerLoopSystems()
	{
        // Try and call PlayerLoopHelper.Init,
        // PlayerLoopHelper.Initialize does not capture unity's sync-context/mainThreadId used by UniTask so we use Init instead.
        AccessTools.Method("Cysharp.Threading.Tasks.PlayerLoopHelper:Init")?.Invoke(null, null);

        if (!Cysharp.Threading.Tasks.PlayerLoopHelper.IsInjectedUniTaskPlayerLoop())
        {
            Logger.LogError("Failed to inject UniTask player loop systems!");
            return;
        }

        if (Cysharp.Threading.Tasks.PlayerLoopHelper.UnitySynchronizationContext == null)
        {
            Logger.LogWarning("Failed to capture Unity Synchronization Context, UniTask may not function properly.");
        }

        // We've modified the current PlayerLoop to include UniTask's systems.
        // Set the current loop so EFT's PlayerLoop modifications preserves UniTask's systems.
        PlayerLoopSystemHelpers._currentLoop = PlayerLoop.GetCurrentPlayerLoop();
    }

#if DEBUG
	private static void TestVContainer()
	{
		var builder = new ContainerBuilder();
		builder.RegisterInstance(BepInEx.Logging.Logger.CreateLogSource("VContainer"));
		builder.RegisterEntryPoint<HelloWorldService>();
		builder.Build();
	}
#endif
}

#if DEBUG
public class HelloWorldService : IStartable
{
	private readonly ManualLogSource _logger;

	public HelloWorldService(ManualLogSource logger)
	{
		_logger = logger;
	}

	public void Start()
	{
		_logger.LogInfo("Hello world! This message means that VContainer was successfully initialized.");
	}
}
#endif
