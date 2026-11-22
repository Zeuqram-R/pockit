import WebKit
import ObjectiveC

/// En pantallas ProMotion (120 Hz), WebKit por defecto limita la página a ~60 cuadros por segundo.
/// Este ajuste interno de WebKit ("Prefer Page Rendering Updates near 60fps") se apaga pa' que el chat y el
/// mapa vayan a 120. Se busca con cuidado: si en otra versión de iOS no existe, no pasa nada.
enum WebPerf {
    static func unlock120(_ prefs: WKPreferences) {
        let cls: AnyClass = WKPreferences.self
        let featuresSel = NSSelectorFromString("_features")
        let setSel = NSSelectorFromString("_setEnabled:forFeature:")
        guard let meta = object_getClass(cls), class_respondsToSelector(meta, featuresSel),
              prefs.responds(to: setSel),
              let features = (cls as AnyObject).perform(featuresSel)?.takeUnretainedValue() as? [NSObject] else { return }
        guard let feature = features.first(where: { ($0.value(forKey: "key") as? String) == "PreferPageRenderingUpdatesNear60FPSEnabled" }),
              let method = class_getInstanceMethod(cls, setSel) else { return }
        typealias Setter = @convention(c) (AnyObject, Selector, Bool, AnyObject) -> Void
        let fn = unsafeBitCast(method_getImplementation(method), to: Setter.self)
        fn(prefs, setSel, false, feature)
    }
}
