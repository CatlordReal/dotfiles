import gzip
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
RENDER = ROOT / "scripts" / "render.py"


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_svg_entity_declaration_is_rejected(self):
        source = self.directory / "entity.svg"
        source.write_text('<!DOCTYPE svg [<!ENTITY size "10">]>'
                          '<svg xmlns="http://www.w3.org/2000/svg" width="&size;" height="10"/>')
        result, _ = self.invoke(source, 10, 20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DTD and entity declarations are not supported", result.stderr)

    def test_gzip_metadata_scan_is_bounded(self):
        source = self.directory / "header.svgz"
        with gzip.open(source, "wb") as handle:
            handle.write(b" " * 1_048_577 + b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"/>')
        result, _ = self.invoke(source, 10, 20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("first 1 MiB", result.stderr)

    def svg(self, name, body, view_box="0 0 10 10"):
        path = self.directory / name
        path.write_text(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s">%s</svg>' % (view_box, body)
        )
        return path

    def invoke(self, source, width, height, *extra):
        output = self.directory / (source.stem + ".png")
        result = subprocess.run(
            [sys.executable, str(RENDER), "--source", str(source), "--output", str(output),
             "--width", str(width), "--height", str(height), *extra],
            text=True, capture_output=True,
        )
        return result, output

    def dimensions(self, path):
        result = subprocess.run(
            ["magick", "identify", "-format", "%w,%h", str(path)], text=True,
            capture_output=True, check=True,
        )
        return tuple(map(int, result.stdout.split(",")))

    def alpha_at(self, path, x, y):
        result = subprocess.run(
            ["magick", str(path), "-format", "%%[pixel:p{%d,%d}]" % (x, y), "info:"],
            text=True, capture_output=True, check=True,
        )
        return result.stdout

    def pixel_at(self, path, x, y):
        result = subprocess.run(
            ["magick", str(path), "-format", "%%[pixel:p{%d,%d}]" % (x, y), "info:"],
            text=True, capture_output=True, check=True,
        )
        return result.stdout

    def test_svg_square_contain_has_exact_canvas_and_centered_geometry(self):
        source = self.svg("square source.svg", '<rect width="10" height="10" fill="red"/>')
        result, output = self.invoke(source, 10, 20, "--fit", "contain")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.dimensions(output), (10, 20))
        data = json.loads(result.stdout)
        self.assertEqual(data["placement"], {"x": 0, "y": 5, "width": 10, "height": 10})
        self.assertTrue(self.alpha_at(output, 0, 0).endswith(",0)"))
        self.assertFalse(self.alpha_at(output, 5, 10).endswith(",0)"))

    def test_rectangular_svg_cover_aligns_and_clips(self):
        source = self.svg(
            "wide.svg", '<rect width="10" height="10" fill="red"/><rect x="10" width="10" height="10" fill="blue"/>',
            "0 0 20 10"
        )
        result, output = self.invoke(
            source, 10, 20, "--fit", "cover", "--align-x", "right", "--align-y", "bottom"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.dimensions(output), (10, 20))
        data = json.loads(result.stdout)
        self.assertEqual(data["placement"], {"x": -30, "y": 0, "width": 40, "height": 20})
        self.assertEqual(self.pixel_at(output, 1, 10), "srgba(0,0,255,1)")
        left_result, left_output = self.invoke(source, 10, 20, "--fit", "cover", "--align-x", "left")
        self.assertEqual(left_result.returncode, 0, left_result.stderr)
        self.assertEqual(self.pixel_at(left_output, 1, 10), "srgba(255,0,0,1)")

    def test_fill_stretches_square_into_canvas(self):
        source = self.svg("fill.svg", '<rect width="10" height="10" fill="red"/>')
        result, output = self.invoke(source, 10, 20, "--fit", "fill")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["placement"], {"x": 0, "y": 0, "width": 10, "height": 20})
        self.assertEqual(self.pixel_at(output, 1, 1), "srgba(255,0,0,1)")
        self.assertEqual(self.pixel_at(output, 8, 18), "srgba(255,0,0,1)")

    def test_viewbox_padding_is_preserved(self):
        source = self.svg("padding.svg", '<rect x="2" y="2" width="6" height="6" fill="red"/>')
        result, output = self.invoke(source, 10, 10, "--fit", "fill")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.alpha_at(output, 0, 0).endswith(",0)"))
        self.assertEqual(self.pixel_at(output, 5, 5), "srgba(255,0,0,1)")

    def test_odd_centered_padding_rounds_within_half_pixel(self):
        source = self.svg("odd.svg", '<rect width="2" height="1" fill="red"/>', "0 0 2 1")
        result, _ = self.invoke(source, 9, 9, "--fit", "contain")
        self.assertEqual(result.returncode, 0, result.stderr)
        placement = json.loads(result.stdout)["placement"]
        self.assertEqual(placement, {"x": 0, "y": 2, "width": 9, "height": 5})
        self.assertLessEqual(abs(placement["y"] - 2.25), 0.5)

    def test_noninteger_svg_intrinsic_size_keeps_metadata_aspect_ratio(self):
        source = self.directory / "fractional.svg"
        source.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="10.5" height="5.25" viewBox="0 0 2 1"><rect width="2" height="1" fill="red"/></svg>')
        result, _ = self.invoke(source, 21, 21, "--fit", "contain")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["placement"], {"x": 0, "y": 5, "width": 21, "height": 11})

    def test_huge_svg_viewbox_is_sized_without_full_intrinsic_raster(self):
        source = self.svg("huge-viewbox.svg", '<rect width="1000000000" height="1000000000" fill="red"/>', "0 0 1000000000 1000000000")
        result, output = self.invoke(source, 10, 10, "--fit", "contain")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.dimensions(output), (10, 10))
        self.assertEqual(json.loads(result.stdout)["placement"], {"x": 0, "y": 0, "width": 10, "height": 10})

    def test_none_honours_native_size_scale_and_alignment(self):
        source = self.svg("native.svg", '<rect width="10" height="10" fill="green"/>')
        result, output = self.invoke(
            source, 30, 20, "--fit", "none", "--scale", "1.5", "--align-x", "right", "--align-y", "bottom"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.dimensions(output), (30, 20))
        self.assertEqual(json.loads(result.stdout)["placement"], {"x": 15, "y": 5, "width": 15, "height": 15})

    def test_raster_first_frame_is_supported(self):
        source = self.directory / "source.gif"
        subprocess.run(["magick", "-size", "4x2", "xc:yellow", str(source)], check=True)
        result, output = self.invoke(source, 8, 8, "--fit", "contain")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.dimensions(output), (8, 8))
        self.assertEqual(json.loads(result.stdout)["placement"], {"x": 0, "y": 2, "width": 8, "height": 4})

    def test_invalid_scale_fails_without_json(self):
        source = self.svg("bad.svg", '<rect width="10" height="10" fill="red"/>')
        result, _ = self.invoke(source, 10, 10, "--scale", "nan")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("scale must be a finite positive number", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_overflowing_scale_fails_without_traceback(self):
        source = self.svg("overflow.svg", '<rect width="10" height="10" fill="red"/>')
        result, _ = self.invoke(source, 10, 10, "--scale", "1e309")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("scale must be a finite positive number", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
