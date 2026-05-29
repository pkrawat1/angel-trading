defmodule AngelTrading.Agent.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @primary_key false
  embedded_schema do
    # Monotonic id assigned on insert; used as the stream dom_id so ordering is stable and two
    # messages with identical text never collide (the old phash2(content) dom_id did).
    field(:id, :integer)

    field(:role, Ecto.Enum,
      values: [:system, :user, :assistant, :function, :function_call],
      default: :user
    )

    field(:hidden, :boolean, default: true)
    field(:content, :string)
  end

  @type t :: %ChatMessage{}

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :hidden, :content])
    |> common_validations()
  end

  @doc false
  def create_changeset(attrs) do
    %ChatMessage{}
    |> cast(attrs, [:role, :hidden, :content])
    |> common_validations()
  end

  defp common_validations(changeset) do
    changeset
    |> validate_required([:role, :hidden, :content])
  end

  def new(params) do
    params
    |> create_changeset()
    |> Map.put(:action, :insert)
    |> apply_action(:insert)
  end
end
