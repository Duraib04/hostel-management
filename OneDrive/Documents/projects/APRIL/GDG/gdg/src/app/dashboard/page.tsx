import Link from "next/link";

const enrolledCourses = [
  {
    name: "Kummi Basics",
    completion: 68,
    nextLesson: "Circle Patterns and Hand Beats",
  },
  {
    name: "Oyilattam Beginner Track",
    completion: 32,
    nextLesson: "Side-Step Variations",
  },
  {
    name: "Karagattam Intro",
    completion: 14,
    nextLesson: "Head Balance and Core Control",
  },
];

const assignmentQueue = [
  {
    title: "Kummi Footwork Practice",
    due: "Due in 2 days",
    status: "Ready to submit",
  },
  {
    title: "Quiz: Folk Origins",
    due: "Due in 4 days",
    status: "Not started",
  },
  {
    title: "Posture Reflection Journal",
    due: "Due in 6 days",
    status: "In progress",
  },
];

export default function StudentDashboardPage() {
  return (
    <main className="mx-auto w-full max-w-6xl flex-1 px-5 py-7 sm:px-7 md:px-10">
      <header className="soft-card mb-6 flex flex-wrap items-center justify-between gap-3 p-5">
        <div>
          <p className="text-xs font-semibold tracking-[0.2em] text-[#7a2e20]">
            STUDENT DASHBOARD
          </p>
          <h1 className="mt-1 text-3xl text-[#1f222b]">Vanakkam, Dancer</h1>
          <p className="mt-2 text-sm text-[#4f535a]">
            Keep your streak alive with one lesson and one practice session today.
          </p>
        </div>
        <Link
          href="/"
          className="rounded-full border border-[#d1b698] px-4 py-2 text-sm font-semibold text-[#7a2e20] hover:bg-[#fff1df]"
        >
          Back to Home
        </Link>
      </header>

      <section className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          ["7", "Day learning streak"],
          ["11", "Lessons completed"],
          ["2", "Assignments pending"],
          ["84%", "Average quiz score"],
        ].map(([value, label], index) => (
          <article
            key={label}
            className="soft-card rise-in p-4"
            style={{ animationDelay: `${index * 90}ms` }}
          >
            <p className="text-3xl font-semibold text-[#7a2e20]">{value}</p>
            <p className="mt-1 text-sm text-[#4f535a]">{label}</p>
          </article>
        ))}
      </section>

      <section className="dashboard-grid">
        <div className="soft-card p-5">
          <h2 className="text-2xl text-[#1f222b]">Your Courses</h2>
          <div className="mt-4 space-y-3">
            {enrolledCourses.map((course) => (
              <article key={course.name} className="rounded-xl border border-[#e7d4bb] p-4">
                <div className="flex items-center justify-between gap-2">
                  <p className="font-semibold text-[#1f222b]">{course.name}</p>
                  <span className="stat-pill">{course.completion}% complete</span>
                </div>
                <p className="mt-2 text-sm text-[#4f535a]">
                  Next: {course.nextLesson}
                </p>
                <div className="mt-3 h-2 rounded-full bg-[#f0dfca]">
                  <div
                    className="h-full rounded-full bg-[#a33e2b]"
                    style={{ width: `${course.completion}%` }}
                  />
                </div>
              </article>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <article className="soft-card p-5">
            <h2 className="text-xl text-[#1f222b]">Today&apos;s Practice Plan</h2>
            <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-[#4f535a]">
              <li>12 min warm-up with ankle and shoulder drills</li>
              <li>20 min Kummi hand-beat timing exercise</li>
              <li>10 min mirror posture review and recording</li>
            </ul>
          </article>

          <article className="soft-card p-5">
            <h2 className="text-xl text-[#1f222b]">Pending Tasks</h2>
            <div className="mt-3 space-y-2">
              {assignmentQueue.map((item) => (
                <div
                  key={item.title}
                  className="rounded-xl border border-[#e7d4bb] px-3 py-2"
                >
                  <p className="text-sm font-semibold text-[#1f222b]">{item.title}</p>
                  <p className="text-xs text-[#5b5f66]">{item.due}</p>
                  <p className="mt-1 text-xs font-semibold text-[#0f6a66]">{item.status}</p>
                </div>
              ))}
            </div>
          </article>
        </div>
      </section>
    </main>
  );
}