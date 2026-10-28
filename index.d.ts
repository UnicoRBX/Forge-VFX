/**
 * Result returned from emitting VFX effects
 */
export interface EmitResult {
  /**
   * Promise that resolves when the effect has finished playing
   */
  Finished: Promise<void>;

  /**
   * Clear all emitted effects
   */
  Clear(): void;
}

/**
 * Initialize the Forge VFX system.
 */
export function init(): void;

/**
 * Clean up and shut down the Forge VFX system.
 * Destroys all caches and disconnects event handlers.
 */
export function deinit(): void;

/**
 * Emit VFX effects from the provided instances.
 * Supports ParticleEmitters, Beams, Trails, Models, and tagged effects.
 * @param instances One or more Roblox instances to emit effects from
 * @returns Result object with a Finished promise
 */
export function emit(...instances: Instance[]): EmitResult;

/**
 * Emit VFX effects with a scale multiplier.
 * @param scale Scale multiplier for the effect
 * @param instances One or more Roblox instances to emit effects from
 * @returns Result object with a Finished promise
 */
export function emit(scale: number, ...instances: Instance[]): EmitResult;

/**
 * Emit VFX effects with a specific render depth.
 * @param depth Render priority depth for the effect
 * @param instances One or more Roblox instances to emit effects from
 * @returns Result object with a Finished promise
 */
export function emitWithDepth(
  depth: number,
  ...instances: Instance[]
): EmitResult;

/**
 * Enable a VFX instance and all its descendants.
 * For ParticleEmitters and Beams, sets the Enabled property directly.
 * For other instances, sets the "Enabled" attribute.
 * @param obj The instance to enable (propagates to descendants)
 */
export function enable(obj: Instance): void;

/**
 * Disable a VFX instance and all its descendants.
 * For ParticleEmitters and Beams, sets the Enabled property directly.
 * For other instances, sets the "Enabled" attribute.
 * @param obj The instance to disable (propagates to descendants)
 */
export function disable(obj: Instance): void;

/**
 * Set how fast every effect plays, including ones already playing.
 * Delays, durations, tweens, particles, beams, trails, sounds, camera shakes
 * and debris all follow it. Particles can't play faster than a TimeScale of 1.
 * @param rate Seconds of effect time per real second, 0 to freeze
 */
export function setRate(rate: number): void;

/**
 * Get the rate set by setRate.
 * @returns Seconds of effect time per real second
 */
export function getRate(): number;

/**
 * Keep an instance and its descendants that the engine runs by itself, such as
 * an enabled ParticleEmitter, Beam, Trail or Sound, at the rate set by setRate.
 * Emitted effects are kept at the rate already.
 * @param obj The instance to keep at the rate (propagates to descendants)
 */
export function track(obj: Instance): void;

/**
 * Stop keeping an instance and its descendants at the rate, putting their
 * speeds back as they were.
 * @param obj The instance to release (propagates to descendants)
 */
export function untrack(obj: Instance): void;

/**
 * Scale the timing of VFX instances by a factor.
 * Adjusts speeds, lifetimes, durations, and rates across all effect types.
 * @param factor The time scale factor (>1 speeds up, <1 slows down)
 * @param instances One or more instances to retime (includes descendants)
 */
export function retime(factor: number, ...instances: Instance[]): void;

/**
 * Scale the size of VFX instances by a factor.
 * Adjusts particle sizes, beam widths, attachment distances, and more.
 * @param factor The size scale factor
 * @param instances One or more instances to resize (includes descendants)
 */
export function resize(factor: number, ...instances: Instance[]): void;

/**
 * Recolor VFX instances.
 * In "replace" mode, sets all colors to the given color (preserving HDR factor).
 * In "multiply" mode, blends the color with existing colors via HSV multiplication.
 * Skips BasePart descendants (only applies to directly passed BaseParts).
 * @param color The target color
 * @param mode "replace" to set colors directly, "multiply" to blend with existing
 * @param instances One or more instances to recolor (includes descendants)
 */
export function recolor(
  color: Color3,
  mode: "replace" | "multiply",
  ...instances: Instance[]
): void;

/**
 * Cache attributes for a VFX instance and optionally its descendants.
 * Strips attributes from instances and stores them in memory for faster access.
 * Only works on the client and for instances inside ReplicatedStorage.
 * @param obj The instance whose attributes to cache
 * @param shallow If true, only cache the instance itself (skip descendants)
 */
export function cacheAttributes(obj: Instance, shallow: boolean): void;

/**
 * Restore previously cached attributes back onto instances.
 * Only works on the client.
 * @param obj The instance whose attributes to restore
 * @param shallow If true, only restore the instance itself (skip descendants)
 */
export function restoreAttributes(obj: Instance, shallow?: boolean): void;
