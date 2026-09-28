.PHONY: analyze test build-apk build-apk-arm64 build-apk-debug run pub-get clean

analyze:
	flutter analyze

test:
	flutter test

build-apk: build-apk-arm64

build-apk-arm64:
	flutter build apk --release --target-platform android-arm64

build-apk-debug:
	flutter build apk --debug

run:
	flutter run

pub-get:
	flutter pub get

clean:
	flutter clean
