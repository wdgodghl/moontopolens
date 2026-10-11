///|
priv struct SequenceTrack {
  id : Int
  observations : Array[SequenceObservation]
}

///|
priv struct SequenceObservation {
  frame : Int
  interval_index : Int
  birth : Double
  death : Double?
  observed_lifetime : Double
}

///|
fn sequence_optional_number(value : Double?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
fn sequence_observation(
  analysis : Analysis,
  frame : Int,
  interval_index : Int,
) -> SequenceObservation {
  let interval = analysis.intervals[interval_index]
  {
    frame,
    interval_index,
    birth: interval.birth,
    death: interval.death,
    observed_lifetime: observed_lifetime(analysis, interval),
  }
}

///|
fn sequence_observation_json(observation : SequenceObservation) -> Json {
  {
    "frame": observation.frame,
    "interval_index": observation.interval_index,
    "birth": observation.birth,
    "death": sequence_optional_number(observation.death),
    "observed_lifetime": observation.observed_lifetime,
    "censored": observation.death is None,
  }
}

///|
fn sequence_h1_indices(analysis : Analysis) -> Array[Int] {
  let indices : Array[Int] = []
  for i = 0; i < analysis.intervals.length(); i = i + 1 {
    if analysis.intervals[i].dimension == 1 {
      indices.push(i)
    }
  }
  indices
}

///|
/// Analyze two to twelve ordered point clouds at one common scale cutoff.
/// H1 tracks use one optimal diagram matching per adjacent pair. Track IDs are
/// diagram correspondences, not verified identities of physical objects.
pub fn topology_sequence(
  text : String,
) -> (Json, String, String, String) raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("sequence request exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid sequence JSON")
  }
  let root = batch_object(parsed, "sequence request")
  batch_fields(root, ["kind", "threshold", "max_cells", "frames"], "sequence")
  if batch_string(root, "kind") != "topology_sequence" {
    raise TopologyError("kind must be topology_sequence")
  }
  let threshold = number_field(root, "threshold")
  if !finite(threshold) || threshold <= 0.0 || threshold > 1.0e100 {
    raise TopologyError("sequence threshold must be finite and positive")
  }
  let budget = integer_field(root, "max_cells", 4000)
  check_budget(0, budget)
  let frame_values = batch_array(root, "frames", true)
  if frame_values.length() < 2 || frame_values.length() > 12 {
    raise TopologyError("sequence requires 2..12 frames")
  }
  let analyses : Array[Analysis] = []
  let names : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let mut coordinate_dimension = 0
  let mut total_cells = 0
  let frames : Array[Json] = []
  let mut frames_csv = "frame,name,point_count,cell_count,h0_at_cutoff,h1_at_cutoff,h1_finite_count,h1_alive_at_cutoff,longest_h1_observed_lifetime\n"
  for value in frame_values {
    let fields = batch_object(value, "sequence frame")
    batch_fields(fields, ["name", "points"], "sequence frame")
    let name = batch_string(fields, "name")
    batch_name(name)
    if seen.contains(name) {
      raise TopologyError("duplicate sequence frame name: " + name)
    }
    seen[name] = true
    let points = rows_field(fields, "points")
    if points.length() < 3 || points.length() > 64 {
      raise TopologyError("sequence frame requires 3..64 points")
    }
    if coordinate_dimension == 0 {
      coordinate_dimension = points[0].length()
    } else if points[0].length() != coordinate_dimension {
      raise TopologyError(
        "sequence frames must use the same coordinate dimension",
      )
    }
    let analysis = analyze(rips(points, threshold~, max_cells=budget))
    total_cells += analysis.filtration.cells.length()
    if total_cells > 16000 {
      raise TopologyError("sequence exceeds 16000 total filtration cells")
    }
    let mut finite_h1 = 0
    let mut alive_h1 = 0
    let mut longest_h1 = 0.0
    for interval in analysis.intervals {
      if interval.dimension == 1 {
        if interval.death is None {
          alive_h1 += 1
        } else {
          finite_h1 += 1
        }
        longest_h1 = maximum(longest_h1, observed_lifetime(analysis, interval))
      }
    }
    let h0 = betti(analysis, 0, threshold)
    let h1 = betti(analysis, 1, threshold)
    let frame_index = frames.length()
    frames.push({
      "index": frame_index,
      "name": name,
      "point_count": points.length(),
      "cell_count": analysis.filtration.cells.length(),
      "h0_at_cutoff": h0,
      "h1_at_cutoff": h1,
      "h1_finite_count": finite_h1,
      "h1_alive_at_cutoff": alive_h1,
      "longest_h1_observed_lifetime": longest_h1,
    })
    frames_csv += "\{frame_index},\{name},\{points.length()},\{analysis.filtration.cells.length()},\{h0},\{h1},\{finite_h1},\{alive_h1},\{longest_h1}\n"
    names.push(name)
    analyses.push(analysis)
  }
  let tracks : Array[SequenceTrack] = []
  let mut previous : Map[Int, Int] = Map([])
  for index in sequence_h1_indices(analyses[0]) {
    let id = tracks.length()
    tracks.push({
      id,
      observations: [sequence_observation(analyses[0], 0, index)],
    })
    previous[index] = id
  }
  let transitions : Array[Json] = []
  let mut transitions_csv = "left_frame,right_frame,left_name,right_name,h0_bottleneck,h1_bottleneck,continued_h1,appeared_h1,disappeared_h1\n"
  for frame = 1; frame < analyses.length(); frame = frame + 1 {
    let left = analyses[frame - 1]
    let right = analyses[frame]
    let h0_distance = compare_analyses(left, right, dimension=0)
    let h1_distance = compare_analyses(left, right, dimension=1)
    let current : Map[Int, Int] = Map([])
    let mut continued = 0
    let mut appeared = 0
    let mut disappeared = 0
    for pair in interval_matching(left, right, dimension=1) {
      match (pair.left, pair.right) {
        (Some(left_index), Some(right_index)) => {
          let id = match previous.get(left_index) {
            Some(id) => id
            None => raise TopologyError("missing previous H1 track")
          }
          current[right_index] = id
          continued += 1
        }
        (None, Some(right_index)) => {
          let id = tracks.length()
          tracks.push({ id, observations: [], })
          current[right_index] = id
          appeared += 1
        }
        (Some(_), None) => disappeared += 1
        (None, None) => ()
      }
    }
    for index in sequence_h1_indices(right) {
      let id = match current.get(index) {
        Some(id) => id
        None => raise TopologyError("missing current H1 track")
      }
      tracks[id].observations.push(sequence_observation(right, frame, index))
    }
    transitions.push({
      "left_frame": frame - 1,
      "right_frame": frame,
      "left_name": names[frame - 1],
      "right_name": names[frame],
      "h0_bottleneck": sequence_optional_number(h0_distance),
      "h1_bottleneck": sequence_optional_number(h1_distance),
      "continued_h1": continued,
      "appeared_h1": appeared,
      "disappeared_h1": disappeared,
    })
    let d0 = match h0_distance {
      Some(d) => d.to_string()
      None => ""
    }
    let d1 = match h1_distance {
      Some(d) => d.to_string()
      None => ""
    }
    transitions_csv += "\{frame - 1},\{frame},\{names[frame - 1]},\{names[frame]},\{d0},\{d1},\{continued},\{appeared},\{disappeared}\n"
    previous = current
  }
  let track_json : Array[Json] = []
  let mut tracks_csv = "track_id,frame,name,interval_index,birth,death,observed_lifetime,censored\n"
  for track in tracks {
    track_json.push({
      "track_id": track.id,
      "observation_count": track.observations.length(),
      "observations": track.observations.map(sequence_observation_json),
    })
    for observation in track.observations {
      let death = match observation.death {
        Some(d) => d.to_string()
        _ => ""
      }
      let censored = if observation.death is None { "true" } else { "false" }
      tracks_csv += "\{track.id},\{observation.frame},\{names[observation.frame]},\{observation.interval_index},\{observation.birth},\{death},\{observation.observed_lifetime},\{censored}\n"
    }
  }
  (
    {
      "schema_version": 1,
      "kind": "topology_sequence",
      "threshold": threshold,
      "coordinate_dimension": coordinate_dimension,
      "frame_count": frames.length(),
      "total_cells": total_cells,
      "track_count": tracks.length(),
      "frames": frames,
      "transitions": transitions,
      "tracks": track_json,
      "interpretation": "adjacent H1 tracks follow one optimal persistence-diagram matching; matches may be nonunique and do not prove physical identity; diagonal matches describe diagram appearance or disappearance, not object creation; null distance means incompatible counts of cutoff-censored classes",
    },
    frames_csv,
    transitions_csv,
    tracks_csv,
  )
}
