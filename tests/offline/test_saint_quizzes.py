import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
QUIZZES_PATH = ROOT / "Klimax" / "saint-quizzes.json"
SAINTS_PATH = ROOT / "Klimax" / "saints.json"


class CuratedSaintQuizTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))
        saints_data = json.loads(SAINTS_PATH.read_text(encoding="utf-8"))
        cls.saint_ids = {
            saint["id"]
            for rank in saints_data["ranks"]
            for saint in rank["saints"]
        }

    def test_every_quiz_targets_a_real_saint(self):
        quiz_ids = [quiz["saintID"] for quiz in self.catalog["quizzes"]]
        self.assertEqual(len(quiz_ids), len(set(quiz_ids)))
        self.assertFalse(set(quiz_ids) - self.saint_ids)

    def test_every_published_quiz_has_ten_distinct_topics(self):
        for quiz in self.catalog["quizzes"]:
            with self.subTest(saint=quiz["saintID"]):
                questions = quiz["questions"]
                self.assertEqual(len(questions), 10)
                self.assertEqual(questions[0]["topic"], "feast")
                self.assertEqual(len({question["topic"] for question in questions}), 10)

    def test_every_question_has_three_unique_answers_and_an_explanation(self):
        for quiz in self.catalog["quizzes"]:
            for question in quiz["questions"]:
                with self.subTest(saint=quiz["saintID"], topic=question["topic"]):
                    answers = [question["correctAnswer"], *question["distractors"]]
                    self.assertEqual(len(question["distractors"]), 2)
                    self.assertEqual(len(set(answers)), 3)
                    self.assertTrue(question["prompt"].strip())
                    self.assertTrue(question["explanation"].strip())

    def test_every_quiz_has_secure_sources(self):
        for quiz in self.catalog["quizzes"]:
            with self.subTest(saint=quiz["saintID"]):
                self.assertTrue(quiz["sourceUrls"])
                self.assertTrue(all(url.startswith("https://") for url in quiz["sourceUrls"]))


if __name__ == "__main__":
    unittest.main()
