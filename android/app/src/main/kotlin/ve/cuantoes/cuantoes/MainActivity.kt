package ve.cuantoes.cuantoes

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val imageExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IMAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != METHOD_CROP_TO_ASPECT_RATIO) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>(ARG_PATH)
            val aspectRatio = call.argument<Double>(ARG_ASPECT_RATIO)
            if (path.isNullOrBlank() || aspectRatio == null ||
                !aspectRatio.isFinite() || aspectRatio <= 0
            ) {
                result.error("invalid_image", "Falta la imagen o la proporción solicitada", null)
                return@setMethodCallHandler
            }

            imageExecutor.execute {
                try {
                    val croppedPath = cropImageToAspectRatio(path, aspectRatio.toFloat())
                    mainHandler.post { result.success(croppedPath) }
                } catch (error: Throwable) {
                    mainHandler.post {
                        result.error(
                            "image_crop_failed",
                            "No se pudo recortar la foto a 4:3",
                            error.javaClass.simpleName,
                        )
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        imageExecutor.shutdown()
        super.onDestroy()
    }

    private fun cropImageToAspectRatio(path: String, targetRatio: Float): String {
        val sourceFile = File(path)
        require(sourceFile.isFile) { "No se encontró la foto capturada" }
        val exif = ExifInterface(sourceFile.absolutePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val decoded = BitmapFactory.decodeFile(sourceFile.absolutePath)
            ?: throw IllegalArgumentException("No se pudo decodificar la foto")

        val rotation = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> rotation.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> rotation.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                rotation.setRotate(180f)
                rotation.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                rotation.setRotate(90f)
                rotation.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> rotation.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                rotation.setRotate(-90f)
                rotation.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> rotation.setRotate(-90f)
        }

        var oriented: Bitmap? = null
        var cropped: Bitmap? = null
        var outputFile: File? = null
        try {
            val orientedBitmap = Bitmap.createBitmap(
                decoded,
                0,
                0,
                decoded.width,
                decoded.height,
                rotation,
                true,
            )
            oriented = orientedBitmap

            val width = orientedBitmap.width
            val height = orientedBitmap.height
            var cropWidth = width
            var cropHeight = height
            var left = 0
            var top = 0
            if (width.toFloat() / height > targetRatio) {
                cropWidth = (height * targetRatio).toInt().coerceAtLeast(1)
                left = (width - cropWidth) / 2
            } else {
                cropHeight = (width / targetRatio).toInt().coerceAtLeast(1)
                top = (height - cropHeight) / 2
            }
            val croppedBitmap = Bitmap.createBitmap(
                orientedBitmap,
                left,
                top,
                cropWidth,
                cropHeight,
            )
            cropped = croppedBitmap

            val outputDirectory = File(cacheDir, "cuantoes-camera-crops")
            if (!outputDirectory.exists() && !outputDirectory.mkdirs()) {
                throw IllegalStateException("No se pudo preparar el archivo temporal")
            }
            val output = File.createTempFile("ocr_4x3_", ".jpg", outputDirectory)
            outputFile = output
            FileOutputStream(output).use { stream ->
                if (!croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)) {
                    throw IllegalStateException("No se pudo guardar la foto recortada")
                }
            }
            ExifInterface(output.absolutePath).apply {
                setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
                saveAttributes()
            }
            return output.absolutePath
        } catch (error: Throwable) {
            outputFile?.delete()
            throw error
        } finally {
            if (cropped != null && cropped !== oriented) cropped.recycle()
            if (oriented != null && oriented !== decoded) oriented.recycle()
            decoded.recycle()
        }
    }

    private companion object {
        const val IMAGE_CHANNEL = "ve.cuantoes/camera_image"
        const val METHOD_CROP_TO_ASPECT_RATIO = "cropToAspectRatio"
        const val ARG_PATH = "path"
        const val ARG_ASPECT_RATIO = "aspectRatio"
    }
}
