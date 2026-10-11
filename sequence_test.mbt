///|
test "ordered frames continue and then end one H1 track" {
  let (report, frames, transitions, tracks) = @moontopolens.topology_sequence(
    "{\"kind\":\"topology_sequence\",\"threshold\":2,\"frames\":[{\"name\":\"square\",\"points\":[[0,0],[1,0],[1,1],[0,1]]},{\"name\":\"expanded\",\"points\":[[0,0],[1.1,0],[1.1,1.1],[0,1.1]]},{\"name\":\"triangle\",\"points\":[[0,0],[1,0],[0.5,0.9]]}]}",
  )
  let output = report.stringify()
  assert_true(output.contains("\"frame_count\":3"))
  assert_true(output.contains("\"track_count\":1"))
  assert_true(output.contains("\"continued_h1\":1"))
  assert_true(output.contains("\"disappeared_h1\":1"))
  assert_true(output.contains("\"observation_count\":2"))
  assert_eq(frames.split("\n").length(), 5)
  assert_eq(transitions.split("\n").length(), 4)
  assert_eq(tracks.split("\n").length(), 4)
  assert_true(
    @moontopolens.topology_sequence_html(report).contains(
      "多帧拓扑变化追踪",
    ),
  )
}

///|
test "unchanged frames have zero distance and preserve H1 track" {
  let (report, _, transitions, _) = @moontopolens.topology_sequence(
    "{\"kind\":\"topology_sequence\",\"threshold\":2,\"frames\":[{\"name\":\"first\",\"points\":[[0,0],[1,0],[1,1],[0,1]]},{\"name\":\"second\",\"points\":[[0,0],[1,0],[1,1],[0,1]]}]}",
  )
  assert_true(report.stringify().contains("\"track_count\":1"))
  assert_true(report.stringify().contains("\"h1_bottleneck\":0"))
  assert_true(transitions.contains("first,second,0,0,1,0,0"))
}

///|
test "censored H1 mismatch keeps null distance" {
  let (report, _, transitions, _) = @moontopolens.topology_sequence(
    "{\"kind\":\"topology_sequence\",\"threshold\":1.2,\"frames\":[{\"name\":\"square\",\"points\":[[0,0],[1,0],[1,1],[0,1]]},{\"name\":\"triangle\",\"points\":[[0,0],[1,0],[0.5,0.9]]}]}",
  )
  assert_true(report.stringify().contains("\"h1_bottleneck\":null"))
  assert_true(report.stringify().contains("\"disappeared_h1\":1"))
  assert_true(transitions.contains("square,triangle,"))
}

///|
test "sequence rejects malformed and incomparable frames" {
  let invalid = [
    "{\"kind\":\"topology_sequence\",\"threshold\":2,\"frames\":[]}", "{\"kind\":\"topology_sequence\",\"threshold\":0,\"frames\":[{},{}]}",
    "{\"kind\":\"topology_sequence\",\"threshold\":2,\"frames\":[{\"name\":\"same\",\"points\":[[0,0],[1,0],[0,1]]},{\"name\":\"same\",\"points\":[[0,0],[1,0],[0,1]]}]}",
    "{\"kind\":\"topology_sequence\",\"threshold\":2,\"frames\":[{\"name\":\"a\",\"points\":[[0,0],[1,0],[0,1]]},{\"name\":\"b\",\"points\":[[0],[1],[2]]}]}",
  ]
  for input in invalid {
    let rejected = try {
      ignore(@moontopolens.topology_sequence(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
