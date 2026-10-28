local ObjectCache = require("@obj/ObjectCache")

export type scope = { any } & {
  depth: number,
  effects: EffectsService,
  _context: { _promises: { any } }?,
  _onCancel: { () -> () }?,
}

export type Promise = {
  andThen: (self: Promise, successHandler: (...any) -> ...any, failureHandler: ((...any) -> ...any)?) -> Promise,
  finally: (self: Promise, finallyHandler: (status: string) -> ...any) -> Promise,
  await: (self: Promise) -> (boolean, ...any),
  cancel: (self: Promise) -> (),
}

export type EmitEnv = {
  Finished: Promise,
  Clear: (self: EmitEnv) -> (),
}

export type ApiCaches = {
  shared_part: ObjectCache.ObjectCache,
}

export type EffectsService = {
  init: (api: Api) -> (),
  deinit: () -> (),

  emit: (depth: number, ...Instance) -> EmitEnv,
  emitNested: (part: Instance, depth: number, parentScope: scope?) -> EmitEnv,
  emitFromFolder: (folder: Folder?, targetParent: Instance, depth: number, parentScope: scope?) -> EmitEnv,
  emitOnFinish: (emitOnFinish: Folder?, targetParent: Instance, depth: number, parentScope: scope?) -> EmitEnv,

  prepareEmitFolder: (obj: Instance, folderName: string, scope: scope) -> Folder?,
  prepareEmitOnFinish: (obj: Instance, scope: scope) -> Folder?,
}

export type Api = {
  setup: boolean,

  scope: { unknown },
  caches: ApiCaches,

  init: (params: any?) -> (),
  deinit: () -> (),

  emit: (vfxOrScale: number | Instance, ...Instance) -> EmitEnv,
  emitWithDepth: (depth: number, ...Instance) -> EmitEnv,
}

return {}
