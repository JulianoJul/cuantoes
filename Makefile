.PHONY: analyze test build-apk build-apk-debug run pub-get clean

analyze:
	flutter analyze

test:
	flutter test

build-apk:
	flutter build apk

build-apk-debug:
	flutter build apk --debug

run:
	flutter run

pub-get:
	flutter pub get

clean:
	flutter clean
