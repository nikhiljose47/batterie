import '../../models/person_status.dart';
import '../../state/async_view_state.dart';

class OthersState {
  const OthersState({
    this.status = AsyncStatus.initial,
    this.people = const <PersonStatus>[],
    this.errorMessage,
  });

  final AsyncStatus status;
  final List<PersonStatus> people;
  final String? errorMessage;

  OthersState copyWith({
    AsyncStatus? status,
    List<PersonStatus>? people,
    String? errorMessage,
  }) {
    return OthersState(
      status: status ?? this.status,
      people: people ?? this.people,
      errorMessage: errorMessage,
    );
  }
}
