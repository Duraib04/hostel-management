import Link from "next/link";

const releasePipeline = [
  {
    lesson: "Kavadi Aattam Intro - Body Alignment",
    stage: "Video upload complete",
    eta: "Schedule for tomorrow",
  },
  {
    lesson: "Karagattam Rhythm Drill",
    stage: "Review notes pending",
    eta: "Needs final check",
  },
  {
    lesson: "Quiz: Folk Costume Elements",
    stage: "Ready to publish",
    eta: "Can go live now",
  },
];

const cohortSignals = [
  ["Kummi Basics", "72% avg completion", "Strong retention"],
  ["Oyilattam Beginner", "39% avg completion", "Needs shorter lessons"],
  ["Karagattam Intro", "21% avg completion", "High replay rate"],
];

export default function InstructorDashboardPage() {
  return (
    <main className="mx-auto w-full max-w-6xl flex-1 px-5 py-7 sm:px-7 md:px-10">
      <header className="soft-card mb-6 flex flex-wrap items-center justify-between gap-3 p-5">
        <div>
          <p className="text-xs font-semibold tracking-[0.2em] text-[#0f6a66]">
            INSTRUCTOR DASHBOARD
          </p>
          <h1 className="mt-1 text-3xl text-[#1f222b]">Content Studio</h1>
          <p className="mt-2 text-sm text-[#4f535a]">
            Publish cultural dance modules with guided practice and measurable learning outcomes.
          </p>
        </div>
        <Link
          href="/"
          className="rounded-full border border-[#98c8c5] px-4 py-2 text-sm font-semibold text-[#0f6a66] hover:bg-[#ddf1ef]"
        >
          Back to Home
        </Link>
      </header>

      <section className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          ["6", "Active courses"],
          ["48", "Lessons published"],
          ["19", "Submissions to review"],
          ["312", "Active learners"],
        ].map(([value, label], index) => (
          <article
            key={label}
            className="soft-card rise-in p-4"
            style={{ animationDelay: `${index * 80}ms` }}
          >
            <p className="text-3xl font-semibold text-[#0f6a66]">{value}</p>
            <p className="mt-1 text-sm text-[#4f535a]">{label}</p>
          </article>
        ))}
      </section>

      <section className="dashboard-grid">
        <div className="space-y-4">
          <article className="soft-card p-5">
            <h2 className="text-2xl text-[#1f222b]">Release Pipeline</h2>
            <div className="mt-4 space-y-3">
              {releasePipeline.map((item) => (
                <div key={item.lesson} className="rounded-xl border border-[#cde3e1] p-4">
                  <p className="font-semibold text-[#1f222b]">{item.lesson}</p>
                  <p className="mt-1 text-sm text-[#495258]">{item.stage}</p>
                  <p className="mt-1 text-xs font-semibold uppercase tracking-[0.08em] text-[#0f6a66]">
                    {item.eta}
                  </p>
                </div>
              ))}
            </div>
          </article>

          <article className="soft-card p-5">
            <h2 className="text-xl text-[#1f222b]">Review Queue</h2>
            <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-[#4f535a]">
              <li>8 practice videos awaiting choreography feedback</li>
              <li>6 quiz appeals from the cultural history module</li>
              <li>5 assignment resubmissions marked as incomplete</li>
            </ul>
          </article>
        </div>

        <div className="soft-card p-5">
          <h2 className="text-2xl text-[#1f222b]">Cohort Performance Pulse</h2>
          <div className="mt-4 space-y-3">
            {cohortSignals.map(([course, completion, insight]) => (
              <article
                key={course}
                className="rounded-xl border border-[#cde3e1] bg-[#f2fbfa] p-4"
              >
                <p className="font-semibold text-[#1f222b]">{course}</p>
                <p className="mt-1 text-sm text-[#495258]">{completion}</p>
                <p className="mt-2 inline-flex rounded-full border border-[#9ccfcb] px-3 py-1 text-xs font-semibold text-[#0f6a66]">
                  {insight}
                </p>
              </article>
            ))}
          </div>
          <button className="mt-5 w-full rounded-full bg-[#0f6a66] px-4 py-3 text-sm font-semibold text-white hover:bg-[#0b4f4c]">
            Open Full Analytics
          </button>
        </div>
      </section>
    </main>
  );
}