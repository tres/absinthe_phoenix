defmodule Absinthe.Phoenix.Channel do
  use Phoenix.Channel
  require Logger

  @doc false
  def __using__(_) do
    raise """
    ----------------------------------------------
    You should `use Absinthe.Phoenix.Socket`
    ----------------------------------------------
    """
  end

  @doc false
  def join("__absinthe__:control", _, socket) do

    absinthe_config = socket.assigns[:absinthe]

    opts =
      absinthe_config
      |> Map.get(:opts, [])
      |> Keyword.update(:context, %{pubsub: socket.endpoint}, fn context ->
        Map.put(context, :pubsub, socket.endpoint)
      end)

    absinthe_config = put_in(absinthe_config[:opts], opts)

    socket = socket |> assign(:absinthe, absinthe_config)
    {:ok, socket}
  end

  @doc false
  def handle_in("doc", payload, socket) do
    config = socket.assigns[:absinthe]

    opts =
      config.opts
      |> Keyword.put(:variables, Map.get(payload, "variables", %{}))

    query = Map.get(payload, "query", "")

    Absinthe.Logger.log_run(:debug, {
      query,
      config.schema,
      [],
      opts,
    })

    result = Absinthe.run(query, config.schema, opts)

    reply = with {:ok, %{"subscribed" => topic}} <- result do
      :ok = Phoenix.PubSub.subscribe(socket.pubsub_server, topic, [
        fastlane: {socket.transport_pid, socket.serializer, []},
        link: true,
      ])

      {:ok, %{subscriptionId: topic}}
    end

    {:reply, reply, socket}
  end

  def handle_in("unsubscribe", %{"subscriptionId" => doc_id}, socket) do
    Phoenix.PubSub.unsubscribe(socket.pubsub_server, doc_id)
    Absinthe.Subscription.unsubscribe(socket.endpoint, doc_id)
    {:reply, {:ok, %{subscriptionId: doc_id}}, socket}
  end

end
