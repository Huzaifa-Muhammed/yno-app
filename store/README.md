# Play Store listing assets

Everything Google Play asks for as an image, at the exact sizes it wants.

| File | Where it goes | Size |
|---|---|---|
| `yno_icon_512.png` | Store listing → App icon | 512×512 |
| `yno_feature_1024x500.png` | Store listing → Feature graphic | 1024×500 |

Still missing: **2–8 phone screenshots**, which need a real device.

## Regenerating the feature graphic

`feature_graphic_source.html` is the source. It is rendered rather than drawn by
hand so the copy and colours can be edited without an image editor, and so it
stays in step with the app's palette (`lib/theme/app_colors.dart`) and with the
welcome screen's own wording, which is where the headline comes from.

    chrome --headless --disable-gpu --hide-scrollbars \
      --force-device-scale-factor=2 --window-size=1024,500 \
      --virtual-time-budget=8000 \
      --screenshot=feature_2x.png feature_graphic_source.html

Rendered at 2x and downscaled to 1024×500, because text scaled down reads far
cleaner than text rendered at final size.

⚠️ **Flatten the result onto an opaque background.** Play rejects a feature
graphic with an alpha channel, and Chrome's screenshot carries one.

⚠️ The page pulls Barlow from Google Fonts, so rendering needs a network
connection. Without it Chrome silently substitutes a default face and the
graphic looks wrong rather than failing.

## Notes on the design

The logo is the client's, used exactly as supplied — navy on its own white
field. It sits in a white chip rather than directly on the dark ground, because
the mark has no transparency of its own and would otherwise read as a white
rectangle cut out of the layout. The chip doubles as a nod to the launcher icon.

The headline and eyebrow are the app's own words (`auth.taglinePlay` /
`taglineEarn` / `taglineRecognised` and `auth.welcomeSubtitle`), so the store
page and the first screen a user sees say the same thing.
