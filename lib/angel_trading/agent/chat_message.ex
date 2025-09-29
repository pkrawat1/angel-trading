defmodule AngelTrading.Agent.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @primary_key false
  embedded_schema do
    field(:id, :string, default: "")
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
    |> cast(attrs, [:id, :role, :hidden, :content])
    |> maybe_set_id()
    |> common_validations()
  end

  @doc false
  def create_changeset(attrs) do
    %ChatMessage{}
    |> cast(attrs, [:id, :role, :hidden, :content])
    |> maybe_set_id()
    |> common_validations()
  end

  defp maybe_set_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, generate_id())
      "" -> put_change(changeset, :id, generate_id())
      _id -> changeset
    end
  end

  defp generate_id do
    "msg_#{:erlang.unique_integer([:positive])}_#{:erlang.system_time(:millisecond)}"
  end

  defp common_validations(changeset) do
    changeset
    |> validate_required([:id, :role, :hidden, :content])
  end

  def new(params) do
    params
    |> create_changeset()
    |> Map.put(:action, :insert)
    |> apply_action(:insert)
  end
end
