import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  PathUtils,
} from '@ohos/flutter_ohos';
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';

/** VideoThumbnailPlugin **/
export default class VideoThumbnailPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "VideoThumbnailPlugin"
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context
  }

  onDetachedFromAbility(): void {
    this.context = null
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.justsoft.xyz/video_thumbnail");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "file") {
      this.generateFile(call, result)
    } else if (call.method == "data") {
      this.generateData(call, result)
    } else {
      result.notImplemented()
    }
  }

  async generateFile(call: MethodCall, result: MethodResult) {
    let videoPath = call.argument("video") as string
    let path = call.argument("path") as string
    let maxh = call.argument("maxh") as number
    let maxw = call.argument("maxw") as number
    let timeMs = call.argument("timeMs") as number
    let quality = call.argument("quality") as number
    let format = call.argument("format") as number
    let fileExt = format == 0 ? "jpg" : (format == 1 ? "png" : "webp")
    let fileMime = format == 0 ? "image/jpeg" : (format == 1 ? "image/png" : "image/webp")
    if (!videoPath || videoPath.length == 0) {
      result.success(null)
      return;
    }
    let thumbFilePath = path + "/video_thumb_" + Date.now() + "." + fileExt
    if (thumbFilePath.indexOf("//") >= 0) {
      thumbFilePath = thumbFilePath.replace("//", "/")
    }
    let pixelMap = await this.getThumbPixelMap(videoPath, maxw, maxh, timeMs * 1000)
    let dstFile = fs.openSync(thumbFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    let packOpts: image.PackingOption = {
      format: fileMime, quality: quality
    };
    const imagePackerApi = image.createImagePacker();
    await imagePackerApi.packToFile(pixelMap, dstFile.fd, packOpts)
    fs.closeSync(dstFile);
    pixelMap.release();
    imagePackerApi.release();
    result.success(thumbFilePath)
  }

  async generateData(call: MethodCall, result: MethodResult) {
    let videoPath = call.argument("video") as string
    let maxh = call.argument("maxh") as number
    let maxw = call.argument("maxw") as number
    let timeMs = call.argument("timeMs") as number
    let quality = call.argument("quality") as number
    let format = call.argument("format") as number
    let fileMime = format == 0 ? "image/jpeg" : (format == 1 ? "image/png" : "image/webp")
    let pixelMap = await this.getThumbPixelMap(videoPath, maxw, maxh, timeMs * 1000)
    const imagePackerApi = image.createImagePacker();
    const packOptions: image.PackingOption = {
      format: fileMime,
      quality: quality,
    }
    let uint8Array: Uint8Array = new Uint8Array(await imagePackerApi.packing(pixelMap, packOptions));
    pixelMap.release();
    imagePackerApi.release();
    result.success(uint8Array);
  }

  async getThumbPixelMap(newPath: string, maxW: number, maxH: number, timeUs: number): Promise<image.PixelMap> {
    let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
    let file = fs.openSync(newPath, fs.OpenMode.READ_ONLY);
    let avFileDescriptor: media.AVFileDescriptor = {
      fd: file.fd
    };
    avImageGenerator.fdSrc = avFileDescriptor;
    let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC
    let param: media.PixelMapParams = {
      width: maxW <= 0 ? 800 : maxW,
      height: maxH <= 0 ? 600 : maxH,
    }
    let pixelMap = await avImageGenerator.fetchFrameByTime(timeUs, queryOption, param)
    avImageGenerator.release()
    fs.closeSync(file);
    return pixelMap
  }
}