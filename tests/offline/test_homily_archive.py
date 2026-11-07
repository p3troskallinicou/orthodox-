import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARCHIVE_PATH = ROOT / "Klimax" / "homily-archive.json"
PROJECT_PATH = ROOT / "Klimax.xcodeproj" / "project.pbxproj"
SPEAKER_VIEW_PATH = ROOT / "Klimax" / "AthosAudioSpeakers.swift"
ATHOS_TV_PATH = ROOT / "Klimax" / "athos_tv_page.json"


class HomilyArchiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.archive = json.loads(ARCHIVE_PATH.read_text(encoding="utf-8"))
        cls.items = cls.archive["items"]
        cls.athos_tv = json.loads(ATHOS_TV_PATH.read_text(encoding="utf-8"))

    def test_complete_catalogue_is_bundled(self):
        self.assertEqual(self.archive["count"], 1850)
        self.assertEqual(len(self.items), 1850)
        self.assertEqual(
            [item["episodeNumber"] for item in self.items],
            list(range(1, 1851)),
        )

    def test_catalogue_identifiers_and_audio_paths_are_unique(self):
        self.assertEqual(len({item["_id"] for item in self.items}), 1850)
        self.assertEqual(len({item["audioPath"] for item in self.items}), 1850)

    def test_every_entry_has_searchable_metadata(self):
        for item in self.items:
            self.assertTrue(item["title"].strip())
            self.assertTrue(item["catalogCode"].strip())
            self.assertTrue(item["searchTerms"].strip())
            self.assertGreater(item["durationSeconds"], 0)
            self.assertEqual(item["mediaType"], "audio")

    def test_catalogue_is_split_into_real_subject_categories(self):
        topics = {item["topic"] for item in self.items}
        self.assertGreaterEqual(len(topics), 20)
        self.assertNotIn("Αρχείο ομιλιών 1850–2022", topics)
        self.assertIn("Γάμος & οἰκογένεια", topics)
        self.assertIn("Προσευχή", topics)
        self.assertIn("Παναγία, Ἅγιοι & βίοι", topics)
        self.assertIn("Ἀκολουθίες & λατρεία", topics)
        self.assertIn("Βυζαντινὴ μουσικὴ & ψαλμωδία", topics)

    def test_speakers_are_normalized_for_profile_pages(self):
        names = {name for item in self.items for name in item["speakers"]}
        self.assertGreaterEqual(len(names), 30)
        self.assertGreaterEqual(sum(bool(item["speakers"]) for item in self.items), 1700)
        for item in self.items:
            expected = " & ".join(item["speakers"]) or None
            self.assertEqual(item["speaker"], expected)

        joined = " ".join(names)
        for ocr_fragment in ("Αβανάσιος", "Mecovatac", "Μεσοναίας", "Φιλοβεῖτης"):
            self.assertNotIn(ocr_fragment, joined)

        referenced_speaker = next(item for item in self.items if item["catalogCode"] == "A00921")
        self.assertEqual(
            referenced_speaker["speakers"],
            ["Μητροπολίτης Λεμεσού Αθανάσιος"],
        )

    def test_collaborative_homilies_keep_each_speaker(self):
        collaborations = [item for item in self.items if len(item["speakers"]) > 1]
        self.assertGreaterEqual(len(collaborations), 3)
        self.assertTrue(
            any("Γεώργιος Μαντζαρίδης" in item["speakers"] for item in collaborations)
        )

    def test_manifest_is_an_application_resource(self):
        project = PROJECT_PATH.read_text(encoding="utf-8")
        self.assertIn("homily-archive.json in Resources", project)

    def test_speaker_profile_interface_is_in_the_app_target(self):
        project = PROJECT_PATH.read_text(encoding="utf-8")
        self.assertTrue(SPEAKER_VIEW_PATH.exists())
        self.assertIn("AthosAudioSpeakers.swift in Sources", project)

    def test_speaker_profile_has_blurred_header_and_no_random_video_action(self):
        source = SPEAKER_VIEW_PATH.read_text(encoding="utf-8")
        self.assertIn(".toolbarBackground(.ultraThinMaterial", source)
        self.assertNotIn('heroButton("Βίντεο"', source)

    def test_athos_tv_uses_canonical_speaker_identity(self):
        audio_speakers = {
            name for item in self.items for name in item.get("speakers", [])
        }
        tagged = [
            video
            for video in self.athos_tv["videos"].values()
            if video.get("speakers")
        ]
        self.assertGreaterEqual(len(tagged), 1300)
        self.assertTrue(
            all(speaker in audio_speakers for video in tagged for speaker in video["speakers"])
        )
        self.assertGreaterEqual(
            sum(
                "Μητροπολίτης Λεμεσού Αθανάσιος" in video["speakers"]
                for video in tagged
            ),
            1391,
        )
        self.assertEqual(
            self.athos_tv["videos"]["jPD75m5XNjY"]["speakers"],
            ["Γέροντας Εφραίμ Βατοπαιδινός"],
        )
        self.assertEqual(
            self.athos_tv["videos"]["vC-i2UKoW_s"]["speakers"],
            ["Γέροντας Ιωσήφ Βατοπαιδινός"],
        )

    def test_tv_and_audio_share_the_same_metropolitan_profile(self):
        audio_speakers = {
            name for item in self.items for name in item.get("speakers", [])
        }
        video_speakers = {
            name
            for video in self.athos_tv["videos"].values()
            for name in video.get("speakers", [])
        }
        self.assertIn("Μητροπολίτης Λεμεσού Αθανάσιος", audio_speakers)
        self.assertIn("Μητροπολίτης Λεμεσού Αθανάσιος", video_speakers)


if __name__ == "__main__":
    unittest.main()
